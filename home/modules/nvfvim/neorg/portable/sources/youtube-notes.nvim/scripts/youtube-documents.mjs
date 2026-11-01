import { metadataPath as workspaceMetadataPath, readData, writeData } from "./youtube-workspace.mjs";
import {
  existsSync,
  lstatSync,
  readFileSync,
  readdirSync,
  statSync,
  writeFileSync,
  renameSync,
  rmSync,
} from "node:fs";
import path from "node:path";
import { location } from "./youtube-notes-structure.mjs";

export const documentStatuses = {
  idea: "Idea",
  planning: "Planning",
  "in-progress": "In progress",
  done: "Done",
  trashed: "Trashed",
};

const slash = (value) => value.split(path.sep).join("/");
const read = (file) => readFileSync(file, "utf8");
const validNote = (note) =>
  typeof note === "string" &&
  note.startsWith("youtube/") &&
  note.endsWith(".norg") &&
  !note.split("/").some((part) => part === ".." || part === "." || part === "");
const validId = (id) =>
  typeof id === "string" &&
  (/^[a-z0-9][a-z0-9-]*$/.test(id) ||
    (id.startsWith("note:") && validNote(id.slice(5))));
const metadataPath = (repoRoot) =>
  workspaceMetadataPath(repoRoot, "documents");

export function documentMetadata(repoRoot) {
  const file = metadataPath(repoRoot);
  if (!existsSync(file)) return { version: 1, items: {} };
  const data = readData(file);
  if (
    data.version !== 1 ||
    !data.items ||
    Array.isArray(data.items) ||
    typeof data.items !== "object"
  )
    throw new Error("Unsupported document metadata");
  for (const [id, item] of Object.entries(data.items)) {
    if (
      !validId(id) ||
      !item ||
      !Object.hasOwn(documentStatuses, item.status) ||
      (item.kind !== undefined &&
        !["video", "guide", "reference"].includes(item.kind)) ||
      (item.title !== undefined &&
        (typeof item.title !== "string" || /[\r\n]/.test(item.title))) ||
      (item.tags !== undefined &&
        (!Array.isArray(item.tags) ||
          item.tags.some(
            (tag) =>
              typeof tag !== "string" || !tag.trim() || /[\r\n]/.test(tag),
          )))
    )
      throw new Error("Invalid document metadata: " + id);
  }
  return data;
}

export function statusFor(metadata, id, fallback = "idea") {
  return metadata.items[id]?.status || fallback;
}

export function sourceTime(files) {
  const dates = files.map((file) => file.updatedAt ? Date.parse(file.updatedAt) : file.absolute && existsSync(file.absolute) ? statSync(file.absolute).mtimeMs : null).filter((date) => date !== null);
  return dates.length ? new Date(Math.max(...dates)).toISOString() : null;
}

const day = (value, timeZone) =>
  value
    ? new Intl.DateTimeFormat("en-CA", {
        timeZone,
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
      }).format(new Date(value))
    : null;

export function currentScripts(production) {
  const scripts = production.files
    .filter((file) => file.spoken)
    .sort((a, b) =>
      a.source.localeCompare(b.source, undefined, { numeric: true }),
    );
  const chapters = scripts.filter((file) =>
    new RegExp("^" + production.id + "-chapter\\d+\\.md$").test(
      path.basename(file.source),
    ),
  );
  return chapters.length ? chapters : scripts;
}

export const words = (text) =>
  text
    .replace(/^\s*<!--\s*title:[^\n]*-->\s*/, "")
    .trim()
    .split(/\s+/)
    .filter(Boolean).length;

export function projectRecords({
  repoRoot,
  productions,
  plan,
  metadata = documentMetadata(repoRoot),
}) {
  const all = new Map(productions);
  for (const event of plan.events)
    if (event.production && !all.has(event.production))
      all.set(event.production, {
        id: event.production,
        title: event.title,
        channel: event.channel,
        files: [],
      });
  const completed = new Set(plan.completedProductions || []);
  return [...all.values()].map((production) => {
    const place = location(production.id);
    const scripts = currentScripts(production);
    const status = statusFor(
      metadata,
      production.id,
      completed.has(production.id) ? "done" : "idea",
    );
    const updatedAt = sourceTime(production.files);
    const dates = plan.events
      .filter(
        (event) =>
          event.production === production.id && event.status !== "done",
      )
      .map((event) => event.date)
      .sort();
    return {
      id: production.id,
      title: metadata.items[production.id]?.title || production.title,
      kind: metadata.items[production.id]?.kind || "video",
      channel: production.channel,
      topic: place.topic,
      note: place.note,
      status,
      statusLabel: documentStatuses[status],
      inherited: false,
      tags: [
        ...new Set([
          place.topic,
          ...(place.earlier ? ["earlier-draft"] : []),
          ...(metadata.items[production.id]?.tags || []),
        ]),
      ],
      plans: production.files.filter((file) => !file.spoken).length,
      scripts: scripts.length,
      words: scripts.reduce((sum, file) => sum + (file.words ?? words(file.text)), 0),
      files: production.files.length,
      updatedAt,
      updated: day(updatedAt, plan.timeZone),
      nextDate: dates[0] || null,
      priority:
        production.id === plan.priorityProduction &&
        !["done", "trashed"].includes(status),
      earlier: place.earlier,
      planNote: production.files.some((file) => !file.spoken)
        ? place.folder + "/planning/index.norg"
        : null,
      scriptNote: scripts.length
        ? place.folder + "/narration/index.norg"
        : null,
    };
  });
}

function physicalNotes(root) {
  if (!existsSync(root)) return [];
  return readdirSync(root, { withFileTypes: true }).flatMap((entry) => {
    if (entry.isSymbolicLink() || entry.name.startsWith(".")) return [];
    const file = path.join(root, entry.name);
    return entry.isDirectory()
      ? physicalNotes(file)
      : entry.isFile() && entry.name.endsWith(".norg")
        ? [file]
        : [];
  });
}

export function documentData({ repoRoot, notesRoot, productions, plan }) {
  const metadata = documentMetadata(repoRoot);
  const projects = projectRecords({ repoRoot, productions, plan, metadata });
  const projectNotes = new Set(projects.map((project) => project.note));
  const byFolder = projects
    .map((project) => ({
      project,
      folder: path.posix.dirname(project.note) + "/",
    }))
    .sort((a, b) => b.folder.length - a.folder.length);
  const sources = new Map(
    [...productions.values()].flatMap((production) =>
      production.files.map((file) => [file.note, file]),
    ),
  );
  const items = [...projects];
  for (const absolute of physicalNotes(path.join(notesRoot, "youtube"))) {
    const note = slash(path.relative(notesRoot, absolute));
    if (projectNotes.has(note)) continue;
    const parent = byFolder.find(({ folder }) =>
      note.startsWith(folder),
    )?.project;
    const source = sources.get(note);
    const text = read(absolute);
    const kind = source
      ? source.spoken
        ? "script"
        : "plan"
      : note.endsWith("/index.norg")
        ? "index"
        : note.includes("/references/") || note.includes("/earlier-")
          ? "reference"
          : "note";
    const id = "note:" + note;
    const status = statusFor(metadata, id, parent?.status || "idea");
    const contents =
      kind === "index"
        ? [...sources.values()].filter((file) =>
            file.note.startsWith(path.posix.dirname(note) + "/"),
          )
        : source
          ? [source]
          : [];
    const updatedAt = source
      ? sourceTime([source])
      : kind === "index"
        ? sourceTime(contents)
        : statSync(absolute).mtime.toISOString();
    const title =
      source?.title ||
      /^title:\s*(.+)$/m.exec(text)?.[1] ||
      /^\*+\s+(.+)$/m.exec(text)?.[1] ||
      path.basename(note, ".norg");
    items.push({
      id,
      title,
      kind,
      note,
      projectId: parent?.id || null,
      projectTitle: parent?.title || null,
      channel:
        parent?.channel ||
        (note.startsWith("youtube/Luix_OS/")
          ? "Luix_OS"
          : note.startsWith("youtube/LuixBits/")
            ? "LuixBits"
            : "Shared"),
      topic:
        parent?.topic ||
        (note.startsWith("youtube/guides/") ? "guides" : "indexes"),
      status,
      statusLabel: documentStatuses[status],
      inherited: Boolean(parent && !metadata.items[id]),
      tags: [
        ...new Set([
          ...(parent?.tags || []),
          ...(metadata.items[id]?.tags || []),
        ]),
      ],
      plans: contents.filter((file) => !file.spoken).length,
      scripts: contents.filter((file) => file.spoken).length,
      words: contents
        .filter((file) => file.spoken)
        .reduce((sum, file) => sum + (file.words ?? words(file.text)), 0),
      files: contents.length || 1,
      updatedAt,
      updated: day(updatedAt, plan.timeZone),
      nextDate: parent?.nextDate || null,
    });
  }
  const ranks = { "in-progress": 0, planning: 1, idea: 2, done: 3, trashed: 4 };
  items.sort(
    (a, b) =>
      Number(Boolean(b.priority)) - Number(Boolean(a.priority)) ||
      ranks[a.status] - ranks[b.status] ||
      Number(Boolean(a.earlier)) - Number(Boolean(b.earlier)) ||
      a.title.localeCompare(b.title) ||
      a.id.localeCompare(b.id),
  );
  return {
    items,
    statuses: documentStatuses,
    counts: Object.fromEntries(
      Object.keys(documentStatuses).map((status) => [
        status,
        projects.filter(
          (project) => project.kind === "video" && project.status === status,
        ).length,
      ]),
    ),
    projects: projects.filter((project) => project.kind === "video").length,
    active: projects.filter(
      (project) =>
        project.kind === "video" &&
        ["planning", "in-progress"].includes(project.status),
    ).length,
    sourceFiles: sources.size,
    sourceScripts: [...sources.values()].filter((file) => file.spoken).length,
  };
}

export function setDocumentStatus({ repoRoot, id, status, documents }) {
  if (!Object.hasOwn(documentStatuses, status))
    throw new Error(
      "Document status must be idea, planning, in-progress, done or trashed",
    );
  if (!validId(id) || !documents.items.some((item) => item.id === id))
    throw new Error("Unknown document: " + id);
  const file = metadataPath(repoRoot);
  if (existsSync(file) && lstatSync(file).isSymbolicLink())
    throw new Error("Refusing a document metadata symlink");
  const metadata = documentMetadata(repoRoot);
  metadata.items[id] = {
    ...metadata.items[id],
    status,
    updatedAt: new Date().toISOString(),
  };
  writeData(file, metadata);
  return metadata.items[id];
}
