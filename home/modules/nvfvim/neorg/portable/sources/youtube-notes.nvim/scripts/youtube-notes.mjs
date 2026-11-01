import { dataPath, readData, writeData, workspaceRoot, isReplica, metadataPath, lockRoot, readCatalog, publishCatalog } from "./youtube-workspace.mjs";
import { createHash } from "node:crypto";
import {
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  readlinkSync,
  renameSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import {
  location,
  groupId,
  eventPage,
  organizeExisting,
  buildIndexes,
} from "./youtube-notes-structure.mjs";
import {
  currentScripts,
  documentData,
  documentMetadata,
  documentStatuses,
  projectRecords,
  setDocumentStatus,
  statusFor,
  sourceTime,
  words,
} from "./youtube-documents.mjs";
import {
  organizeNotesHome,
  syncWorkspaceIndexes,
  workspaceIndexSignature,
} from "./notes-index.mjs";

const checkout = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const begin = "@comment\nluix-youtube:begin\n@end\n";
const end = "@comment\nluix-youtube:end\n@end";
const states = new Set(["planned", "in-progress", "done"]);
const digest = (text) => createHash("sha256").update(text).digest("hex");
const read = (file) => readFileSync(file, "utf8");
const json = (file) => JSON.parse(read(file));
const slash = (value) => value.split(path.sep).join("/");
const titleText = (value) =>
  String(value)
    .replace(/[\r\n]/g, " ")
    .replace(/[\[\]{}]/g, "")
    .trim();
const link = (relative, label) =>
  `{:$/` + relative.replace(/\.norg$/, "") + `:}[${titleText(label)}]`;

export function validDate(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value))
    throw new Error("Use a date in YYYY-MM-DD form");
  const date = new Date(`${value}T12:00:00Z`);
  if (
    !Number.isFinite(date.getTime()) ||
    date.toISOString().slice(0, 10) !== value
  ) {
    throw new Error(`Invalid date: ${value}`);
  }
  return value;
}

export function validTime(value) {
  if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(value))
    throw new Error("Use a time in HH:MM form (00:00–23:59)");
  return value;
}

function todayIn(timeZone = "Europe/Zurich") {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

function atomic(file, text) {
  mkdirSync(path.dirname(file), { recursive: true });
  const temporary = `${file}.${process.pid}.tmp`;
  try {
    writeFileSync(temporary, text, { mode: 0o600 });
    renameSync(temporary, file);
  } finally {
    rmSync(temporary, { force: true });
  }
}

function loadPlan(repoRoot) {
  const plan = readData(metadataPath(repoRoot, "plan"));
  if (plan.version !== 1 || !Array.isArray(plan.events))
    throw new Error("Unsupported YouTube plan");
  const ids = new Set();
  for (const event of plan.events) {
    if (!/^[a-z0-9][a-z0-9-]*$/.test(event.id) || ids.has(event.id))
      throw new Error(`Invalid or duplicate event ID: ${event.id}`);
    ids.add(event.id);
    validDate(event.date);
    if (event.time !== undefined) validTime(event.time);
    if (
      !states.has(event.status) ||
      !["LuixBits", "Luix_OS"].includes(event.channel)
    )
      throw new Error(`Invalid event: ${event.id}`);
    if (
      !event.title ||
      (event.production && !/^[a-z0-9][a-z0-9-]*$/.test(event.production))
    )
      throw new Error(`Invalid production: ${event.id}`);
  }
  return plan;
}

function walk(directory) {
  if (!existsSync(directory)) return [];
  return readdirSync(directory, { withFileTypes: true })
    .sort((a, b) => a.name.localeCompare(b.name))
    .flatMap((entry) => {
      const file = path.join(directory, entry.name);
      if (entry.isSymbolicLink()) return [];
      return entry.isDirectory()
        ? walk(file)
        : entry.isFile() && file.endsWith(".md")
          ? [file]
          : [];
    });
}

export function catalog(repoRoot = checkout) {
  if (isReplica(repoRoot)) return readCatalog(repoRoot);
  const root = path.join(repoRoot, "docs/video-scripts");
  const productions = new Map();
  const files = new Map();
  for (const absolute of walk(root)) {
    const relative = slash(path.relative(root, absolute));
    const parts = relative.split("/");
    const stem = path.basename(relative, ".md");
    const legacyChapter =
      parts.length === 1 && /^(.+)-chapter(\d+)$/.exec(stem);
    const id = parts.length > 1 ? parts[0] : groupId(stem);
    if (!/^[a-z0-9][a-z0-9-]*$/.test(id)) continue;
    const source = slash(path.relative(repoRoot, absolute));
    const text = read(absolute);
    const spoken = /^\s*<!--\s*title:\s*([^\n]+?)\s*-->/.exec(text);
    const isSpoken = Boolean(
      spoken ||
        /-chapter\d+$/.test(stem) ||
        /^daily-nixos-day\d+$/.test(id) ||
        (parts.length === 1 && !/^#\s/m.test(text)),
    );
    const title =
      spoken?.[1] ??
      /^#\s+(.+)$/m.exec(text)?.[1] ??
      (legacyChapter ? `Chapter ${legacyChapter[2]}` : stem);
    const leaf =
      parts.length === 1
        ? legacyChapter
          ? `narration/${stem}`
          : isSpoken
            ? "narration/script"
            : "planning/plan"
        : `${isSpoken ? "narration" : "planning"}/${parts
            .slice(1)
            .join("/")
            .replace(/\.md$/, "")
            .replace(/(^|\/)index$/, "$1source-index")}`;
    const place = location(id);
    const note = `${place.folder}/${leaf}.norg`;
    const item = {
      production: id,
      source,
      absolute,
      note,
      title: titleText(title),
      spoken: isSpoken,
      text,
    };
    files.set(source, item);
    if (!productions.has(id))
      productions.set(id, {
        id,
        title: item.title,
        channel: place.channel,
        files: [],
      });
    const production = productions.get(id);
    production.files.push(item);
    if (stem === id || (parts.length === 1 && !legacyChapter))
      production.title = item.title;
  }
  for (const production of productions.values()) {
    if (
      /^daily-nixos-day\d+$/.test(production.id) &&
      production.title === production.id
    )
      production.title = `Daily NixOS Info · Day ${Number(production.id.match(/\d+$/)[0])}`;
    if (
      production.id === "nixos-one-year" &&
      production.title === production.id
    )
      production.title = "One year with NixOS";
    if (
      production.id === "nixos-rebuild" &&
      production.files.every((item) => item.spoken)
    )
      production.title = "nixos-rebuild: rebuilding a NixOS system";
    if (production.id === "roomplan")
      production.title = "Roomplan: the Neovim floor planner";
    production.note = location(production.id).note;
  }
  return { productions, files };
}

function inline(text, source, files, repoRoot) {
  return text
    .replace(
      /!\[([^\]]*)\]\(([^)]+)\)/g,
      (_, label, url) => `[Image: ${label}] ${url}`,
    )
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, label, target) => {
      if (/^https?:\/\//.test(target))
        return `{${target}}[${titleText(label)}]`;
      const [file] = target.split("#");
      if (!file) return titleText(label);
      const resolved = slash(
        path.relative(
          repoRoot,
          path.resolve(path.dirname(path.join(repoRoot, source)), file),
        ),
      );
      if (files.has(resolved)) return link(files.get(resolved).note, label);
      return titleText(label) + ` (${target})`;
    })
    .replace(/\*\*([^*]+)\*\*/g, "*$1*");
}

export function markdownToNorg(
  text,
  {
    source = "docs/video-ideas.md",
    files = new Map(),
    repoRoot = checkout,
    headingOffset = 0,
  } = {},
) {
  const lines = text
    .replace(/^\s*<!--\s*title:[^\n]+-->\s*\n/, "")
    .split(/\r?\n/);
  const result = [];
  let code = false;
  let fence = "";
  let tableHeaders;
  for (const line of lines) {
    const marker = /^\s*(`{3,}|~{3,})(.*)$/.exec(line);
    if (
      marker &&
      (!code || (marker[1][0] === fence[0] && marker[1].length >= fence.length))
    ) {
      if (code) {
        result.push("@end");
        code = false;
      } else {
        fence = marker[1];
        result.push(`@code ${marker[2].trim().split(/\s/)[0] || "text"}`);
        code = true;
      }
      continue;
    }
    if (code) {
      result.push(line === "@end" ? "\\@end" : line);
      continue;
    }
    if (/^\s*<!--.*-->\s*$/.test(line)) continue;
    if (/^\|.*\|\s*$/.test(line)) {
      const cells = line
        .trim()
        .slice(1, -1)
        .split(/(?<!\\)\|/)
        .map((cell) => inline(cell.trim(), source, files, repoRoot));
      if (cells.every((cell) => /^:?-+:?$/.test(cell))) continue;
      if (!tableHeaders) {
        tableHeaders = cells;
        continue;
      }
      result.push(
        `- ${cells.map((cell, i) => `${tableHeaders[i] || i + 1}: ${cell}`).join("; ")}`,
      );
      continue;
    }
    tableHeaders = undefined;
    const heading = /^(#{1,6})\s+(.+)$/.exec(line);
    if (heading)
      result.push(
        `${"*".repeat(Math.min(6, heading[1].length + headingOffset))} ${inline(heading[2], source, files, repoRoot)}`,
      );
    else if (/^\s*[-*_]{3,}\s*$/.test(line)) result.push("___");
    else result.push(inline(line, source, files, repoRoot));
  }
  if (code) result.push("@end");
  return result.join("\n").trim();
}

function meta(title, category = "youtube") {
  return `@document.meta\ntitle: ${titleText(title)}\nauthors: Luix\ncategories: ${category}\n@end\n\n`;
}

function safeTarget(root, relative) {
  if (path.isAbsolute(relative) || relative.split(/[\\/]/).includes(".."))
    throw new Error(`Unsafe note path: ${relative}`);
  const target = path.resolve(root, relative);
  let current = root;
  for (const part of relative.split("/")) {
    current = path.join(current, part);
    try {
      if (lstatSync(current).isSymbolicLink())
        throw new Error(`Refusing a symlink note: ${relative}`);
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
  }
  return target;
}

function writer(notesRoot, state) {
  const result = { updated: 0, unchanged: 0, conflicts: [] };
  function write(
    relative,
    title,
    body,
    {
      append = false,
      journal = false,
      category = "youtube",
      scope = "youtube",
    } = {},
  ) {
    const ownership =
      scope === "notes" ? (state.notesIndexHashes ||= {}) : state.files;
    const target = safeTarget(notesRoot, relative);
    const current = existsSync(target) ? read(target) : "";
    const start = current.indexOf(begin);
    const stop = current.indexOf(end, start < 0 ? 0 : start + begin.length);
    // An authored day keeps its own headings. Generated-only days gain a date
    // above the YouTube subsection, inside the existing owned region.
    const prefix = current.slice(0, start < 0 ? current.length : start)
      .replace(/@document\.meta[\s\S]*?@end/, "").trim();
    const managed = (journal && !prefix ? `* ${title}\n\n` : "") + body.trim() + "\n";
    let next;
    if (
      start >= 0 &&
      stop > start &&
      current.indexOf(begin, start + begin.length) === -1
    ) {
      const previous = current.slice(start + begin.length, stop);
      if (previous !== managed && digest(previous) !== ownership[relative]) {
        result.conflicts.push(relative);
        return;
      }
      next =
        current.slice(0, start + begin.length) + managed + current.slice(stop);
    } else if (start >= 0 || stop >= 0) {
      result.conflicts.push(relative);
      return;
    } else if (current && !append) {
      // A note that predates this bridge belongs to the user.
      result.conflicts.push(relative);
      return;
    } else {
      next =
        (current ? current.trimEnd() + "\n\n" : meta(title, category)) +
        begin +
        managed +
        end +
        "\n";
      if (!append) next += "\n* My notes\n\n";
    }
    if (journal) {
      // These metadata labels were generated by the old bridge. Preserve all
      // personal content and other category choices.
      next = next.replace(/^@document\.meta[\s\S]*?@end/, (metadata) =>
        metadata.replace(/^categories: youtube$/m, "categories: journal"));
      const before = next
        .slice(0, next.indexOf(begin))
        .replace(/@document\.meta[\s\S]*?@end/, "")
        .trim();
      const after = next.slice(next.indexOf(end) + end.length).trim();
      if (!before && !after) next += "\n* Notes\n\n";
    }
    ownership[relative] = digest(managed);
    if (current === next) result.unchanged++;
    else {
      atomic(target, next);
      result.updated++;
    }
  }
  return { write, result };
}

const journalPath = (date) => `journal/${date.replaceAll("-", "/")}.norg`;
const eventNote = eventPage;
const eventLine = (event) =>
  `- (${event.status === "done" ? "x" : event.status === "in-progress" ? "-" : " "}) ${event.time ? `${event.time} · ` : ""}${event.channel}: ${event.proposal ? "Idea · " : ""}${link(eventNote(event), event.title)}${event.action ? ` — ${event.action}` : ""}`;
const eventOrder = (a, b) =>
  a.date.localeCompare(b.date) ||
  (a.time || "24:00").localeCompare(b.time || "24:00") ||
  a.id.localeCompare(b.id);

export function monthCalendar(month, events) {
  validDate(`${month}-01`);
  const first = new Date(`${month}-01T12:00:00Z`);
  const days = new Date(
    Date.UTC(first.getUTCFullYear(), first.getUTCMonth() + 1, 0),
  ).getUTCDate();
  const offset = (first.getUTCDay() + 6) % 7;
  const scheduled = new Set(
    events
      .filter((event) => event.status !== "done")
      .map((event) => event.date),
  );
  const cells = Array.from({ length: offset }, () => "    ");
  for (let day = 1; day <= days; day++) {
    const date = `${month}-${String(day).padStart(2, "0")}`;
    cells.push(
      link(
        journalPath(date),
        `${String(day).padStart(2, "0")}${scheduled.has(date) ? "+" : ""}`,
      ) + (scheduled.has(date) ? "" : " "),
    );
  }
  const title = new Intl.DateTimeFormat("en-GB", {
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(first);
  const lines = [`** ${title}`, "Mon  Tue  Wed  Thu  Fri  Sat  Sun"];
  for (let i = 0; i < cells.length; i += 7)
    lines.push(cells.slice(i, i + 7).join("  "));
  return lines.join("\n");
}

function locked(workRoot, action) {
  mkdirSync(workRoot, { recursive: true });
  const lock = path.join(workRoot, "sync.lock");
  const deadline = Date.now() + 5000;
  for (;;) {
    try {
      mkdirSync(lock);
      break;
    } catch (error) {
      if (error.code !== "EEXIST") throw error;
    }
    let alive = true;
    try {
      const owner = json(path.join(lock, "owner.json"));
      try {
        process.kill(owner.pid, 0);
      } catch (error) {
        if (error.code === "ESRCH") alive = false;
        else throw error;
      }
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
      try {
        alive = Date.now() - lstatSync(lock).mtimeMs < 5000;
      } catch (error) {
        if (error.code !== "ENOENT") throw error;
        continue;
      }
    }
    if (!alive) {
      rmSync(lock, { recursive: true, force: true });
      continue;
    }
    if (Date.now() >= deadline)
      throw new Error("Another notes sync is still active; retry shortly");
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 25);
  }
  try {
    writeFileSync(
      path.join(lock, "owner.json"),
      JSON.stringify({ pid: process.pid }),
    );
    return action();
  } finally {
    rmSync(lock, { recursive: true, force: true });
  }
}

export function syncNotes({
  repoRoot = checkout,
  notesRoot = process.env.LUIX_NOTES_ROOT || path.join(homedir(), "notes"),
  today,
  extraDate,
} = {}) {
  repoRoot = path.resolve(repoRoot);
  notesRoot = path.resolve(notesRoot);
  const workRoot = lockRoot(repoRoot);
  return locked(workRoot, () => {
    const plan = loadPlan(repoRoot);
    today = validDate(today || todayIn(plan.timeZone));
    if (extraDate) validDate(extraDate);
    const stateFile = metadataPath(repoRoot, "state");
    const state = existsSync(stateFile)
      ? readData(stateFile)
      : { version: 1, notesRoot, files: {}, journalDates: [] };
    if (!workspaceRoot(repoRoot) && state.notesRoot !== notesRoot)
      throw new Error(
        "This checkout is already syncing a different notes root; use a separate checkout for a second notes destination",
      );
    mkdirSync(notesRoot, { recursive: true });
    const { write, result } = writer(notesRoot, state);
    const { productions, files } = catalog(repoRoot);
    const metadata = documentMetadata(repoRoot);
    const documents = projectRecords({ repoRoot, productions, plan, metadata });
    const documentById = new Map(documents.map((item) => [item.id, item]));
    const statusControl = (id, note, status) =>
      `Status: ${documentStatuses[status]}\n@comment\nyoutube-document: ${id}\n@end\n${link(note, "Change status")}`;
    if (!isReplica(repoRoot)) for (const item of files.values()) {
      const content = markdownToNorg(item.text, {
        source: item.source,
        files,
        repoRoot,
      });
      const status = statusFor(
        metadata,
        `note:${item.note}`,
        documentById.get(item.production).status,
      );
      write(
        item.note,
        item.title,
        `Source: \`${item.source}\`.\n\n${statusControl(`note:${item.note}`, item.note, status)}\n\n${content}`,
      );
    }
    for (const event of plan.events) {
      if (event.production && !productions.has(event.production)) {
        productions.set(event.production, {
          id: event.production,
          title: event.title,
          channel: event.channel,
          files: [],
        });
      } else if (!event.production) {
        write(
          eventNote(event),
          event.title,
          `* ${titleText(event.title)}\n\n${link(path.posix.dirname(eventPage(event)) + "/index.norg", "Planned episodes")}  ·  ${link("youtube/index.norg", "YouTube overview")}\n\n${event.channel} · ${event.date}\n\nThis day's video has not been chosen yet. ${link(journalPath(event.date), "Open this day's journal")} and use Options to choose a prepared video.\n\nIts plan and narration will appear together once chosen.`,
        );
      }
    }
    if (!isReplica(repoRoot)) for (const production of productions.values()) {
      const allScripts = production.files
        .filter((item) => item.spoken)
        .sort((a, b) =>
          a.source.localeCompare(b.source, undefined, { numeric: true }),
        );
      const scripts = currentScripts(production);
      const plans = production.files.filter((item) => !item.spoken);
      const primary =
        plans.find(
          (item) => path.basename(item.source) === `${production.id}.md`,
        ) || plans[0];
      const references = [
        ...plans.filter((item) => item !== primary),
        ...allScripts.filter((item) => !scripts.includes(item)),
      ];
      const document = documentById.get(production.id);
      if (document.kind !== "video") {
        write(
          location(production.id).note,
          document.title,
          [
            `* ${document.title}`,
            "",
            link("youtube/reference/index.norg", "Production reference"),
            "",
            document.kind === "guide"
              ? "Series planning and reference material."
              : "Earlier version of a released production.",
            "",
            statusControl(
              production.id,
              location(production.id).note,
              document.status,
            ),
            "",
            "* Source documents",
            ...production.files.map(
              (item) => `- ${link(item.note, item.title)}`,
            ),
          ].join("\n"),
        );
        continue;
      }
      const body = [
        `* ${production.title}`,
        link(location(production.id).topicNote, "Topic index") +
          "  ·  " +
          link("youtube/index.norg", "YouTube overview"),
        "",
        `Channel: ${production.channel}`,
        statusControl(
          production.id,
          location(production.id).note,
          document.status,
        ),
        `Plans: ${document.plans} · Scripts: ${document.scripts} · Narration: ${document.words} words`,
        `Source updated: ${document.updated || "no source yet"}${document.nextDate ? " · Next calendar date: " + document.nextDate : ""}`,
        "",
        "{* Plan}[Plan]  ·  {* Narration}[Narration]  ·  {* My notes}[My notes]",
        "",
        "The plan describes the video. Narration contains the words to record. Put feedback under My notes. Backspace returns to the previous page.",
        "",
        "* Plan",
      ];
      if (primary) {
        body.push(
          markdownToNorg(primary.text.replace(/^\s*# [^\n]+\n/, ""), {
            source: primary.source,
            files,
            repoRoot,
            headingOffset: 1,
          }),
        );
      } else
        body.push(
          "This video is planned. Its plan will appear here when written.",
        );
      body.push("", "* Narration");
      for (const [index, item] of scripts.entries()) {
        body.push(
          "",
          `** ${String(index + 1).padStart(2, "0")} ${item.title}`,
          "",
          markdownToNorg(item.text, { source: item.source, files, repoRoot }),
        );
      }
      if (!scripts.length)
        body.push(
          "Narration will appear here when written. Gameplay may use the recorded commentary instead.",
        );
      if (references.length)
        body.push(
          "",
          "* Reference material",
          ...references.map((item) => `- ${link(item.note, item.title)}`),
        );
      for (const [folder, title] of [
        ["notes", "Personal and earlier notes"],
        ["references", "Earlier pages and references"],
      ]) {
        if (
          existsSync(
            path.join(notesRoot, location(production.id).folder, folder),
          )
        )
          body.push(
            "",
            link(
              `${location(production.id).folder}/${folder}/index.norg`,
              title,
            ),
          );
      }
      write(location(production.id).note, production.title, body.join("\n"));
    }
    if (isReplica(repoRoot)) {
      // Notes already contain authored plans and narration. Change only their
      // generated status controls, preserving the source text and personal notes.
      const records = documentData({ repoRoot, notesRoot, productions, plan }).items;
      for (const record of records) {
        const target = safeTarget(notesRoot, record.note);
        if (!existsSync(target)) continue;
        const text = read(target);
        const start = text.indexOf(begin), stop = text.indexOf(end, start + begin.length);
        if (start < 0 || stop < 0) continue;
        let body = text.slice(start + begin.length, stop);
        if (!body.includes(`youtube-document: ${record.id}\n`)) continue;
        if (digest(body) !== state.files[record.note]) {
          result.conflicts.push(record.note);
          continue;
        }
        body = body.replace(/Status: [^\n]+(?=\n@comment\nyoutube-document:)/, `Status: ${record.statusLabel}`);
        if (record.kind === "video") body = body.replace(/^(Source updated: [^\n·]+)(?: · Next calendar date: [^\n]+)?$/m, (_, source) => source.trimEnd() + (record.nextDate ? " · Next calendar date: " + record.nextDate : ""));
        write(record.note, record.title, body);
      }
    }
    const ledger = path.join(repoRoot, "docs/video-ideas.md");
    if (existsSync(ledger))
      write(
        "youtube/guides/channel-plan.norg",
        "YouTube production plan",
        markdownToNorg(read(ledger), { files, repoRoot }),
      );
    const dates = [
      ...new Set([
        ...state.journalDates,
        ...plan.events.map((event) => event.date),
        today,
        ...(extraDate ? [extraDate] : []),
      ]),
    ].sort();
    for (const date of dates) {
      const events = plan.events
        .filter((event) => event.date === date)
        .sort(eventOrder);
      const body = [
        "** YouTube",
        "",
        "Open a video for its plan and narration. Options changes its date or progress.",
        "",
      ];
      for (const event of events) {
        const status = {
          planned: "Planned",
          "in-progress": "In progress",
          done: "Done",
        }[event.status];
        body.push(
          `*** ${event.title}`,
          `${event.channel} · ${event.kind === "release" && event.status === "planned" ? "Scheduled release" : event.status === "planned" && documentById.get(event.production)?.status === "idea" ? "Proposed topic" : status}${event.time ? ` · ${event.time} (${plan.timeZone})` : ""}`,
          ...(event.action ? [event.action] : []),
          "",
          `- ${link(eventNote(event), "Plan and narration")}`,
          "@comment",
          `youtube-task: ${event.id}`,
          "@end",
          `- ${link(journalPath(date), "Options")}`,
          "",
        );
      }
      if (!events.length) body.push("No video tasks scheduled for this date.");
      write(journalPath(date), date, body.join("\n"), {
        append: true,
        journal: true,
        category: "journal",
      });
    }
    state.journalDates = dates;
    const ordered = plan.events
      .map((event) => ({
        ...event,
        proposal: documentById.get(event.production)?.status === "idea",
      }))
      .sort(eventOrder);
    const schedule = [
      "* Video schedule",
      "",
      "Three LuixBits videos and two Luix_OS Star Citizen videos weekly.",
      "Open a journal day. Each video entry has its plan, narration and Options.",
    ];
    for (const date of [...new Set(ordered.map((event) => event.date))]) {
      schedule.push(
        "",
        `** ${date}`,
        link(journalPath(date), "Open journal"),
        ...ordered.filter((event) => event.date === date).map(eventLine),
      );
    }
    write(
      "youtube/guides/schedule.norg",
      "Video schedule",
      schedule.join("\n"),
    );
    buildIndexes({ notesRoot, productions, plan, documents, today, write });
    if (!syncWorkspaceIndexes({ notesRoot, today, state, write }))
      write(
        "index.norg",
        "Notes",
        "* Video production\n\n" +
          link("youtube/index.norg", "YouTube overview") +
          "\n\nIndex: Space n y i. Dashboard: Space n y d. Calendar: Space n j c. Journal: Space n j j.",
        { append: true },
      );
    if (workspaceRoot(repoRoot)) delete state.notesRoot;
    writeData(stateFile, state);
    const shared = workspaceRoot(repoRoot);
    if (shared && !isReplica(repoRoot)) publishCatalog(shared, { productions, files }, sourceTime, words);
    return {
      ...result,
      productions: productions.size,
      scripts: [...files.values()].filter((item) => item.spoken).length,
    };
  });
}

export function updateEvent(repoRoot, id, changes) {
  const workRoot = lockRoot(repoRoot);
  return locked(workRoot, () => {
    const plan = loadPlan(repoRoot);
    const event = plan.events.find((item) => item.id === id);
    if (!event) throw new Error(`Unknown event: ${id}`);
    if (changes.date) validDate(changes.date);
    if (changes.time !== undefined) validTime(changes.time);
    if (changes.status && !states.has(changes.status))
      throw new Error("Status must be planned, in-progress or done");
    if (
      changes.production &&
      !catalog(repoRoot).productions.has(changes.production)
    )
      throw new Error("Assign an existing canonical production");
    Object.assign(event, changes);
    if (changes.production)
      event.title = catalog(repoRoot).productions.get(changes.production).title;
    writeData(metadataPath(repoRoot, "plan"), plan);
    return event;
  });
}

// Records an upload already scheduled by Luix. This never contacts YouTube.
export function scheduleRelease(repoRoot, production, date, time) {
  validDate(date);
  validTime(time);
  return locked(lockRoot(repoRoot), () => {
    const plan = loadPlan(repoRoot);
    const video = catalog(repoRoot).productions.get(production);
    if (!video) throw new Error("Schedule an existing canonical production");
    const id = `${production}-release`;
    let event = plan.events.find((item) => item.id === id);
    if (event && event.kind !== "release")
      throw new Error("The release ID is already used by another task");
    if (!event) {
      event = { id };
      plan.events.push(event);
    }
    Object.assign(event, {
      kind: "release",
      phase: "Release",
      date,
      time,
      channel: video.channel,
      production,
      title: documentMetadata(repoRoot).items[production]?.title || video.title,
      action: "Uploaded to YouTube; scheduled release.",
      status: "planned",
    });
    writeData(metadataPath(repoRoot, "plan"), plan);
    return event;
  });
}

export function dashboardData({
  repoRoot = checkout,
  today,
  notesRoot = process.env.LUIX_NOTES_ROOT || path.join(homedir(), "notes"),
} = {}) {
  const plan = loadPlan(repoRoot);
  today = validDate(today || todayIn(plan.timeZone));
  const documents = documentData({
    repoRoot,
    notesRoot,
    productions: catalog(repoRoot).productions,
    plan,
  });
  const byProduction = new Map(
    documents.items
      .filter((item) => item.kind === "video")
      .map((item) => [item.id, item]),
  );
  const events = plan.events
    .map((event) => ({
      ...event,
      proposal: byProduction.get(event.production)?.status === "idea",
    }))
    .sort(eventOrder);
  const pending = events.filter((event) => event.status !== "done");
  const active = documents.items.filter((item) => {
    if (
      item.kind !== "video" ||
      !["planning", "in-progress"].includes(item.status)
    )
      return false;
    const tasks = events.filter((event) => event.production === item.id);
    return !tasks.length || tasks.some((event) => event.status !== "done");
  });
  const next =
    active.find((item) => item.id === plan.priorityProduction) || active[0];
  const priority = next ? { id: next.id, title: next.title } : null;
  const horizon = new Date(`${today}T12:00:00Z`);
  horizon.setUTCDate(horizon.getUTCDate() + 7);
  const until = horizon.toISOString().slice(0, 10);
  const dateAt = (date, offset) => {
    const value = new Date(`${date}T12:00:00Z`);
    value.setUTCDate(value.getUTCDate() + offset);
    return value.toISOString().slice(0, 10);
  };
  const monday = dateAt(
    today,
    -((new Date(`${today}T12:00:00Z`).getUTCDay() + 6) % 7),
  );
  const weeks = [0, 7].map((offset, index) => ({
    label: index === 0 ? "This week" : "Next week",
    start: dateAt(monday, offset),
    end: dateAt(monday, offset + 6),
    days: Array.from({ length: 7 }, (_, day) => {
      const date = dateAt(monday, offset + day);
      return { date, events: events.filter((event) => event.date === date) };
    }),
  }));
  return {
    today,
    tomorrow: dateAt(today, 1),
    weeks,
    library: "youtube/index.norg",
    documents,
    timeZone: plan.timeZone,
    priority,
    events,
    counts: {
      today: pending.filter((event) => event.date === today).length,
      overdue: pending.filter((event) => event.date < today).length,
      upcoming: pending.filter(
        (event) => event.date >= today && event.date < until,
      ).length,
      done: events.filter((event) => event.status === "done").length,
    },
  };
}

export function updateDocument(
  repoRoot,
  id,
  status,
  {
    notesRoot = process.env.LUIX_NOTES_ROOT || path.join(homedir(), "notes"),
  } = {},
) {
  return locked(lockRoot(repoRoot), () =>
    setDocumentStatus({
      repoRoot,
      id,
      status,
      documents: documentData({
        repoRoot,
        notesRoot,
        productions: catalog(repoRoot).productions,
        plan: loadPlan(repoRoot),
      }),
    }),
  );
}

export function installNeovim({ repoRoot = checkout, nvimConfig } = {}) {
  if (!nvimConfig) {
    const probe = spawnSync(
      "nvim",
      [
        "-u",
        "NONE",
        "-i",
        "NONE",
        "--headless",
        "+lua io.write(vim.fn.stdpath('config'))",
        "+qa",
      ],
      { encoding: "utf8" },
    );
    if (probe.status !== 0 || !probe.stdout.startsWith("/"))
      throw new Error("Cannot resolve Neovim config; pass --nvim-config");
    nvimConfig = probe.stdout.trim();
  }
  const source = path.join(
    repoRoot,
    "nvim/youtube-notes/plugin/youtube-notes.lua",
  );
  const target = path.join(nvimConfig, "plugin/luix-youtube-notes.lua");
  mkdirSync(path.dirname(target), { recursive: true });
  try {
    const stat = lstatSync(target);
    if (
      !stat.isSymbolicLink() ||
      path.resolve(path.dirname(target), readlinkSync(target)) !== source
    )
      throw new Error(`Refusing to replace another Neovim plugin: ${target}`);
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
    symlinkSync(source, target);
  }
  return { installed: target };
}

// One-time migration: portable mutable state belongs to the notes repository.
export function exportWorkspace({ repoRoot = checkout, notesRoot }) {
  if (!notesRoot || path.resolve(notesRoot) === path.resolve(repoRoot)) throw new Error("Choose the notes checkout for shared data");
  if (workspaceRoot(repoRoot)) throw new Error("This publisher already uses a shared workspace");
  if (existsSync(dataPath(notesRoot, "catalog"))) throw new Error("A shared workspace already exists; refusing to replace it");
  const existing = catalog(repoRoot);
  const plan = loadPlan(repoRoot), documents = documentMetadata(repoRoot);
  const state = readData(metadataPath(repoRoot, "state"));
  if (state.notesRoot !== notesRoot) throw new Error("Sync this notes checkout before migrating its workspace");
  delete state.notesRoot;
  writeData(dataPath(notesRoot, "plan"), plan);
  writeData(dataPath(notesRoot, "documents"), documents);
  writeData(dataPath(notesRoot, "state"), state);
  publishCatalog(notesRoot, existing, sourceTime, words);
  writeData(path.join(repoRoot, "private/work/youtube-notes/workspace.json"), { version: 1, notesRoot });
  return { workspace: notesRoot, productions: existing.productions.size };
}

function main() {
  const args = process.argv.slice(2);
  const command = args.shift() || "sync";
  const options = {};
  const positional = [];
  while (args.length) {
    const arg = args.shift();
    if (arg.startsWith("--")) {
      const key = {
        "--repo-root": "repoRoot",
        "--notes-root": "notesRoot",
        "--today": "today",
        "--nvim-config": "nvimConfig",
        "--note": "note",
      }[arg];
      if (!key || !args.length)
        throw new Error(`Unknown or incomplete option: ${arg}`);
      options[key] = args.shift();
    } else positional.push(arg);
  }
  const repoRoot = path.resolve(options.repoRoot || (process.env.YOUTUBE_NOTES_PORTABLE === "1" ? options.notesRoot || process.env.LUIX_NOTES_ROOT || path.join(homedir(), "notes") : checkout));
  if (process.env.YOUTUBE_NOTES_PORTABLE === "1" && !workspaceRoot(repoRoot))
    throw new Error("Sync your notes first to load the shared YouTube workspace (Space n g s).");
  options.repoRoot = repoRoot;
  const report = (result) => {
    console.log(JSON.stringify(result));
    if (result.conflicts?.length) process.exitCode = 1;
  };
  if (command === "export-workspace") { report(exportWorkspace({ repoRoot, notesRoot: options.notesRoot })); return; }
  if (command === "list") {
    report(
      loadPlan(repoRoot).events.map((event) => ({
        ...event,
        note: eventPage(event),
      })),
    );
    return;
  }
  if (command === "overview") {
    report(dashboardData(options));
    return;
  }
  if (command === "documents") {
    report(dashboardData(options).documents);
    return;
  }
  if (command === "document-status") {
    updateDocument(repoRoot, positional[0], positional[1], options);
    report(syncNotes(options));
    return;
  }
  if (command === "schedule-release") {
    if (positional.length !== 3)
      throw new Error(
        "schedule-release needs a production ID, YYYY-MM-DD and HH:MM",
      );
    const result = scheduleRelease(repoRoot, ...positional);
    if (result?.busy)
      throw new Error("Another sync is active; retry the action");
    report(syncNotes(options));
    return;
  }
  if (command === "video") {
    report({ note: location(positional[0]).note });
    return;
  }
  if (command.startsWith("organize") && workspaceRoot(repoRoot)) throw new Error("The shared notes layout is already organized");
  if (command === "organize") {
    const notesRoot = path.resolve(
      options.notesRoot ||
        process.env.LUIX_NOTES_ROOT ||
        path.join(homedir(), "notes"),
    );
    const organized = locked(
      path.join(repoRoot, "private/work/youtube-notes"),
      () =>
        organizeExisting({
          repoRoot,
          notesRoot,
          plan: loadPlan(repoRoot),
          sourceFiles: catalog(repoRoot).files,
        }),
    );
    report({ ...organized, ...syncNotes({ ...options, notesRoot }) });
    return;
  }
  if (command === "organize-notes") {
    const notesRoot = path.resolve(
      options.notesRoot ||
        process.env.LUIX_NOTES_ROOT ||
        path.join(homedir(), "notes"),
    );
    const today = validDate(
      options.today || todayIn(loadPlan(repoRoot).timeZone),
    );
    const organized = locked(
      path.join(repoRoot, "private/work/youtube-notes"),
      () => organizeNotesHome({ repoRoot, notesRoot, today }),
    );
    report({ ...organized, ...syncNotes({ ...options, notesRoot, today }) });
    return;
  }
  if (command === "catalog") {
    report(
      projectRecords({
        repoRoot,
        productions: catalog(repoRoot).productions,
        plan: loadPlan(repoRoot),
      }).map(({ id, title, channel, kind, status, files }) => ({
        id,
        title,
        channel,
        kind,
        status,
        files,
      })),
    );
    return;
  }
  if (command === "install") {
    report(installNeovim(options));
    return;
  }
  if (command === "source") {
    const notesRoot = path.resolve(
      options.notesRoot ||
        process.env.LUIX_NOTES_ROOT ||
        path.join(homedir(), "notes"),
    );
    const relative = slash(
      path.relative(notesRoot, path.resolve(options.note || "")),
    );
    const item = [...catalog(repoRoot).files.values()].find(
      (item) => item.note === relative,
    );
    if (!item)
      throw new Error(
        "This note has no single canonical source; open a plan or narration note first",
      );
    report({ source: item.absolute });
    return;
  }
  if (["move", "status", "assign"].includes(command)) {
    if (positional.length !== 2)
      throw new Error(`${command} needs an event ID and a value`);
    const change = {
      [command === "move"
        ? "date"
        : command === "status"
          ? "status"
          : "production"]: positional[1],
    };
    const result = updateEvent(repoRoot, positional[0], change);
    if (result?.busy)
      throw new Error("Another sync is active; retry the action");
    report(syncNotes(options));
    return;
  }
  if (command === "journal") {
    options.extraDate = validDate(positional[0]);
    report(syncNotes(options));
    return;
  }
  if (command === "sync") {
    report(syncNotes(options));
    return;
  }
  if (command !== "watch") throw new Error(`Unknown command: ${command}`);
  let previous = "";
  const poll = () => {
    try {
      const inputs = [
        ...walk(path.join(repoRoot, "docs/video-scripts")),
        path.join(repoRoot, "docs/video-ideas.md"),
        metadataPath(repoRoot, "plan"),
        metadataPath(repoRoot, "documents"),
        ...(workspaceRoot(repoRoot) ? [dataPath(workspaceRoot(repoRoot), "catalog")] : []),
      ];
      const signature = digest(
        inputs
          .filter(existsSync)
          .map((file) => `${file}:${digest(read(file))}`)
          .join("\n") +
          (options.today || todayIn(loadPlan(repoRoot).timeZone)) +
          (existsSync(
            metadataPath(repoRoot, "state"),
          ) &&
          readData(metadataPath(repoRoot, "state"))
            .notesHomeVersion === 1
            ? workspaceIndexSignature(
                options.notesRoot ||
                  process.env.LUIX_NOTES_ROOT ||
                  path.join(homedir(), "notes"),
              )
            : ""),
      );
      if (signature !== previous) {
        const result = syncNotes(options);
        if (!result.busy) {
          report(result);
          previous = signature;
        }
      }
    } catch (error) {
      console.error(error.message);
    }
  };
  poll();
  const timer = setInterval(poll, 1500);
  for (const signal of ["SIGINT", "SIGTERM"])
    process.on(signal, () => {
      clearInterval(timer);
      process.exit(0);
    });
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    main();
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
