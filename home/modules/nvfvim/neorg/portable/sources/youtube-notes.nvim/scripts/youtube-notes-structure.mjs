import { createHash } from "node:crypto";
import {
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  renameSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import { norgLinks } from "./norg-table.mjs";

const slash = (value) => value.split(path.sep).join("/");
const hash = (value) => createHash("sha256").update(value).digest("hex");
const read = (file) => readFileSync(file, "utf8");
const exists = (file) => {
  try {
    lstatSync(file);
    return true;
  } catch (e) {
    if (e.code === "ENOENT") return false;
    throw e;
  }
};
const human = (value) =>
  ({
    ai: "AI",
    nixos: "NixOS",
    neovim: "Neovim",
    tools: "Linux tools",
    projects: "Projects",
    shorts: "Shorts",
    guides: "Guides",
    "star-citizen": "Star Citizen",
    narration: "Narration chapters",
    planning: "Plan references",
    notes: "Personal and earlier notes",
    "earlier-drafts": "Earlier drafts",
    references: "Reference material",
    "earlier-pages": "Earlier chapter pages",
    "older-notes": "Earlier notes",
    "planned-slots": "Planned episodes",
  })[value] || value.replaceAll("-", " ");
const label = (text) =>
  String(text)
    .replace(/[\[\]{}\r\n]/g, " ")
    .trim();
const link = (file, text) =>
  `{:$/` + file.replace(/\.norg$/, "") + `:}[${label(text)}]`;

export function groupId(id) {
  return /^(.+)-chapter\d+$/.exec(id)?.[1] || id;
}

export function location(id) {
  id = groupId(id);
  if (!/^[a-z0-9][a-z0-9-]*$/.test(id))
    throw new Error(`Invalid video ID: ${id}`);
  let channel = "LuixBits",
    topic = "projects";
  if (id.startsWith("star-citizen-")) {
    channel = "Luix_OS";
    topic = "star-citizen";
  } else if (/^(daily-nixos-|gaming-short-)|shorts/.test(id)) topic = "shorts";
  else if (/series-plan$|series$/.test(id)) topic = "guides";
  else if (/^(strata|openclaw|ai-)/.test(id)) topic = "ai";
  else if (/^(neovim|roomplan|obsidian-vs-neorg)/.test(id)) topic = "neovim";
  else if (/^(nix-|nixos-|ryoku-nixos|herdr|home-manager)/.test(id))
    topic = "nixos";
  else if (
    /^(ripgrep|jq|git-worktree|fzf|journalctl|tmux|recording-organizer|viewer-followup)/.test(
      id,
    )
  )
    topic = "tools";
  const earlier = /^openclaw-nixos(?:-v[23])?$/.test(id);
  const folder = `youtube/${channel}/${topic}/${earlier ? "earlier-drafts/" : ""}${id}`;
  return {
    id,
    channel,
    topic,
    earlier,
    folder,
    note: `${folder}/index.norg`,
    topicNote: `youtube/${channel}/${topic}/index.norg`,
  };
}

export const eventPage = (event) =>
  event.production
    ? location(event.production).note
    : `youtube/${event.channel}/${event.channel === "Luix_OS" ? "star-citizen" : "projects"}/planned-slots/${event.id}.norg`;

function physicalNotes(root) {
  if (!existsSync(root)) return [];
  return readdirSync(root, { withFileTypes: true }).flatMap((entry) => {
    if (entry.isSymbolicLink() || entry.name.startsWith(".")) return [];
    const file = path.join(root, entry.name);
    return entry.isDirectory()
      ? physicalNotes(file)
      : entry.isFile() && file.endsWith(".norg")
        ? [file]
        : [];
  });
}

function movedPath(file, moves) {
  const match = [...moves]
    .sort((a, b) => b.from.length - a.from.length)
    .find((move) => file === move.from || file.startsWith(move.from + "/"));
  return match ? match.to + file.slice(match.from.length) : file;
}

function rewriteRelativeLinks(text, from, moves) {
  let code = false;
  return text
    .split("\n")
    .map((line) => {
      if (/^@code\b/.test(line)) {
        code = true;
        return line;
      }
      if (code) {
        if (/^@end\s*$/.test(line)) code = false;
        return line;
      }
      return line.replace(
        /\{:([^:$\/][^:}]*)(:[^}]*\})/g,
        (_, target, suffix) => {
          const destination = path.posix.normalize(
            path.posix.join(path.posix.dirname(from), target),
          );
          if (destination.startsWith("../")) return `{:${target}${suffix}`;
          const extension = destination.endsWith(".norg") ? "" : ".norg";
          const mapped = movedPath(destination + extension, moves);
          return (
            `{:$/` +
            (extension ? mapped.replace(/\.norg$/, "") : mapped) +
            suffix
          );
        },
      );
    })
    .join("\n");
}

/** Reversible note moves; canonical Markdown and all media remain untouched. */
export function organizeExisting({
  repoRoot,
  notesRoot,
  plan,
  sourceFiles = new Map(),
}) {
  const work = path.join(repoRoot, "private/work/youtube-notes");
  const stateFile = path.join(work, "state.json");
  const state = existsSync(stateFile)
    ? JSON.parse(read(stateFile))
    : { version: 1, notesRoot, files: {}, journalDates: [] };
  if (state.notesRoot !== notesRoot)
    throw new Error(
      "The notes destination differs from the existing sync state",
    );
  if (state.organizationVersion === 2)
    return { moved: 0, alreadyOrganized: true };
  const moves = [];
  const add = (from, to, alias = true) => {
    const source = path.join(notesRoot, from);
    if (exists(source) && !lstatSync(source).isSymbolicLink())
      moves.push({ from, to, alias });
  };
  if (!state.organizationVersion) {
    const videos = path.join(notesRoot, "youtube/videos");
    if (existsSync(videos))
      for (const entry of readdirSync(videos, { withFileTypes: true })) {
        if (!entry.isDirectory()) continue;
        const destination = location(entry.name).folder;
        add(
          `youtube/videos/${entry.name}`,
          groupId(entry.name) !== entry.name
            ? `${destination}/references/earlier-pages/${entry.name}`
            : destination,
        );
        if (groupId(entry.name) === entry.name)
          for (const file of ["plan.norg", "narration.norg"]) {
            add(
              `youtube/videos/${entry.name}/${file}`,
              `${destination}/references/earlier-exports/${file}`,
            );
          }
      }
    const slots = path.join(notesRoot, "youtube/slots");
    if (existsSync(slots))
      for (const entry of readdirSync(slots, { withFileTypes: true })) {
        if (!entry.isFile() || !entry.name.endsWith(".norg")) continue;
        const id = entry.name.slice(0, -5);
        const event = plan.events.find((event) => event.id === id) || {
          id,
          channel: "Luix_OS",
        };
        add(`youtube/slots/${entry.name}`, eventPage(event));
      }
    add("youtube/shorts", "youtube/LuixBits/shorts/older-notes");
    const root = path.join(notesRoot, "youtube");
    if (existsSync(root))
      for (const entry of readdirSync(root, { withFileTypes: true })) {
        if (!entry.isFile() || !entry.name.endsWith(".norg")) continue;
        const name = entry.name;
        let destination = `youtube/guides/${name}`;
        if (/roomplan/i.test(name))
          destination = `${location("roomplan").folder}/notes/${name}`;
        else if (/flashcards/i.test(name))
          destination = `${location("neovim-flashcards").folder}/notes/${name}`;
        else if (name === "index.norg")
          destination = "youtube/guides/earlier-overview.norg";
        else if (name === "dashboard.norg")
          destination = "youtube/guides/earlier-dashboard.norg";
        else if (name === "library.norg")
          destination = "youtube/guides/earlier-library.norg";
        else if (name === "production-plan.norg")
          destination = "youtube/guides/channel-plan.norg";
        add(`youtube/${name}`, destination, name !== "index.norg");
      }
  }
  // Older scripts without title headers were exported as planning documents.
  // Move those owned copies with the same backup and alias guarantees.
  for (const file of Object.keys(state.files)) {
    const staged = movedPath(file, moves);
    if (!staged.includes("/planning/") || staged.includes("/references/"))
      continue;
    const absolute = path.join(notesRoot, file);
    if (!existsSync(absolute)) continue;
    const source = /^Source: `([^`\n]+)`\./m.exec(read(absolute))?.[1];
    const desired = sourceFiles.get(source)?.note;
    if (desired && desired !== staged) add(file, desired);
  }
  moves.sort(
    (a, b) =>
      a.to.split("/").length - b.to.split("/").length ||
      a.to.localeCompare(b.to),
  );
  for (const move of moves)
    if (exists(path.join(notesRoot, move.to)))
      throw new Error(`Organization destination already exists: ${move.to}`);
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  const receiptRoot = path.join(work, "migrations", stamp);
  mkdirSync(receiptRoot, { recursive: true });
  writeFileSync(
    path.join(receiptRoot, "previous-state.json"),
    JSON.stringify(state, null, 2),
    { mode: 0o600 },
  );
  const records = [];
  const backedUp = new Set();
  for (const move of moves) {
    const source = path.join(notesRoot, move.from);
    for (const file of physicalNotes(
      lstatSync(source).isDirectory() ? source : path.dirname(source),
    )) {
      const relative = slash(path.relative(notesRoot, file));
      if (relative !== move.from && !relative.startsWith(move.from + "/"))
        continue;
      if (backedUp.has(relative)) continue;
      backedUp.add(relative);
      const content = read(file),
        backup = path.join(receiptRoot, "originals", relative);
      mkdirSync(path.dirname(backup), { recursive: true });
      writeFileSync(backup, content, { mode: 0o600 });
      records.push({
        from: relative,
        to: movedPath(relative, moves),
        sha256: hash(content),
      });
    }
  }
  const receipt = {
    version: 1,
    notesRoot,
    moves,
    files: records,
    complete: false,
  };
  const receiptFile = path.join(receiptRoot, "receipt.json");
  writeFileSync(receiptFile, JSON.stringify(receipt, null, 2), { mode: 0o600 });
  const applied = [];
  for (const move of moves) {
    const source = path.join(notesRoot, move.from),
      target = path.join(notesRoot, move.to);
    const physicalSource = path.join(notesRoot, movedPath(move.from, applied));
    mkdirSync(path.dirname(target), { recursive: true });
    renameSync(source, target);
    if (move.alias)
      symlinkSync(
        path.relative(path.dirname(physicalSource), target),
        source,
        lstatSync(target).isDirectory() ? "dir" : "file",
      );
    applied.push(move);
  }
  const files = {};
  for (const [file, digest] of Object.entries(state.files))
    files[movedPath(file, moves)] = digest;
  if (moves.some((move) => move.from === "youtube/index.norg"))
    delete files["youtube/index.norg"];
  for (const record of records) {
    const file = path.join(notesRoot, record.to),
      original = read(file);
    if (hash(original) !== record.sha256)
      throw new Error(`Moved note changed unexpectedly: ${record.to}`);
    const rewritten = rewriteRelativeLinks(original, record.from, moves);
    if (rewritten !== original) {
      const before =
        /@comment\nluix-youtube:begin\n@end\n([\s\S]*?)@comment\nluix-youtube:end\n@end/.exec(
          original,
        )?.[1];
      const after =
        /@comment\nluix-youtube:begin\n@end\n([\s\S]*?)@comment\nluix-youtube:end\n@end/.exec(
          rewritten,
        )?.[1];
      if (before && after && files[record.to] === hash(before))
        files[record.to] = hash(after);
      writeFileSync(file, rewritten, { mode: 0o600 });
    }
  }
  state.files = files;
  state.organizationVersion = 2;
  writeFileSync(stateFile, JSON.stringify(state, null, 2) + "\n", {
    mode: 0o600,
  });
  receipt.complete = true;
  writeFileSync(receiptFile, JSON.stringify(receipt, null, 2), { mode: 0o600 });
  return {
    moved: moves.length,
    preservedFiles: records.length,
    receipt: slash(path.relative(repoRoot, receiptFile)),
  };
}

export function buildIndexes({
  notesRoot,
  productions,
  plan,
  documents = [],
  today,
  write,
}) {
  const documentById = new Map(documents.map((item) => [item.id, item]));
  const documentStates = [
    ["in-progress", "In progress"],
    ["planning", "Planning"],
    ["idea", "Ideas"],
    ["done", "Released"],
    ["trashed", "Trashed"],
  ];
  const documentLine = (production) => {
    const item = documentById.get(production.id);
    return `- ${link(location(production.id).note, item?.title || production.title)}${item ? ` · ${item.status === "done" ? "Released" : item.statusLabel} · Plan: ${item.plans ? "available" : "no separate plan"} · Narration: ${item.scripts === 1 ? "1 script" : item.scripts ? `${item.scripts} chapters` : "not written"}` : ""}`;
  };
  const documentLinks = (entries) =>
    norgLinks(
      ["Video", "Status", "Narration"],
      entries.map((production) => {
        const item = documentById.get(production.id);
        return [
          link(location(production.id).note, item?.title || production.title),
          item?.status === "done" ? "Done" : item?.statusLabel || "Idea",
          item?.scripts === 1
            ? "1 script"
            : item?.scripts
              ? `${item.scripts} chapters`
              : "Not written",
        ];
      }),
    );
  const eventByNote = new Map(
    plan.events.map((event) => [eventPage(event), event]),
  );
  const projectNotes = new Set(
    [...productions.values()].map((p) => location(p.id).note),
  );
  const topicFolders = new Set(
    [...productions.values()].map(
      (p) => `youtube/${location(p.id).channel}/${location(p.id).topic}`,
    ),
  );
  for (const event of plan.events.filter((event) => !event.production))
    topicFolders.add(path.posix.dirname(path.posix.dirname(eventPage(event))));
  const specialIndexes = new Set([
    ...projectNotes,
    ...[...topicFolders].map((folder) => `${folder}/index.norg`),
    "youtube/LuixBits/index.norg",
    "youtube/Luix_OS/index.norg",
    "youtube/ideas/index.norg",
    "youtube/released/index.norg",
    "youtube/reference/index.norg",
  ]);
  const all = physicalNotes(path.join(notesRoot, "youtube"));
  const ancestors = new Set();
  for (const file of all) {
    let folder = slash(path.relative(notesRoot, path.dirname(file)));
    while (folder.startsWith("youtube/")) {
      ancestors.add(folder);
      folder = path.posix.dirname(folder);
    }
  }
  const folders = [...ancestors].filter(
    (folder) =>
      !folder.startsWith("youtube/videos") &&
      !folder.startsWith("youtube/slots"),
  );
  for (const folder of folders.sort((a, b) => b.length - a.length)) {
    const index = `${folder}/index.norg`;
    if (specialIndexes.has(index)) continue;
    const entries = readdirSync(path.join(notesRoot, folder), {
      withFileTypes: true,
    })
      .filter(
        (entry) =>
          !entry.isSymbolicLink() &&
          !entry.name.startsWith(".") &&
          entry.name !== "index.norg",
      )
      .sort(
        (a, b) =>
          Number(b.isDirectory()) - Number(a.isDirectory()) ||
          a.name.localeCompare(b.name),
      );
    const parent = `${path.posix.dirname(folder)}/index.norg`;
    const lines = [
      `* ${human(path.posix.basename(folder))}`,
      "",
      link(parent, "Up"),
      "",
    ];
    for (const entry of entries) {
      const child = `${folder}/${entry.name}`;
      if (entry.isDirectory()) {
        if (existsSync(path.join(notesRoot, child, "index.norg"))) {
          const content = read(path.join(notesRoot, child, "index.norg"));
          const title =
            /^title:\s*(.+)$/m.exec(content)?.[1] || human(entry.name);
          lines.push(`- ${link(`${child}/index.norg`, title)}`);
        }
      } else if (entry.name.endsWith(".norg")) {
        const title =
          /^title:\s*(.+)$/m.exec(read(path.join(notesRoot, child)))?.[1] ||
          human(entry.name.slice(0, -5));
        const event = eventByNote.get(child);
        lines.push(
          `- ${link(child, event ? `${event.date} · ${title}` : title)}`,
        );
      }
    }
    write(index, human(path.posix.basename(folder)), lines.join("\n"), {
      append: true,
    });
  }
  // Parent directories may contain only folders, so create their indexes explicitly.
  const topics = new Map();
  for (const production of productions.values()) {
    const place = location(production.id);
    const key = `youtube/${place.channel}/${place.topic}`;
    if (!topics.has(key)) topics.set(key, []);
    topics.get(key).push(production);
  }
  for (const event of plan.events.filter((event) => !event.production)) {
    const folder = path.posix.dirname(path.posix.dirname(eventPage(event)));
    if (!topics.has(folder)) topics.set(folder, []);
  }
  for (const [folder, projects] of topics) {
    const lines = [
      `* ${human(path.posix.basename(folder))}`,
      "",
      link(`${path.posix.dirname(folder)}/index.norg`, "Channel"),
      "",
    ];
    for (const [status, heading] of documentStates) {
      const chosen = projects
        .filter(
          (p) =>
            !location(p.id).earlier &&
            (documentById.get(p.id)?.kind || "video") === "video" &&
            (documentById.get(p.id)?.status || "idea") === status,
        )
        .sort((a, b) => a.title.localeCompare(b.title));
      if (chosen.length) lines.push(`** ${heading}`, documentLinks(chosen), "");
    }
    const references = projects.filter(
      (p) =>
        ["guide", "reference"].includes(documentById.get(p.id)?.kind) &&
        !location(p.id).earlier,
    );
    if (references.length)
      lines.push("** Reference", documentLinks(references), "");
    if (projects.some((p) => location(p.id).earlier))
      lines.push(link(`${folder}/earlier-drafts/index.norg`, "Earlier drafts"));
    if (existsSync(path.join(notesRoot, folder, "planned-slots/index.norg")))
      lines.push(
        link(
          `${folder}/planned-slots/index.norg`,
          "Planned episodes: choose their recordings",
        ),
      );
    const older = `${folder}/older-notes/index.norg`;
    if (existsSync(path.join(notesRoot, older)))
      lines.push(link(older, "Earlier notes"));
    write(
      `${folder}/index.norg`,
      human(path.posix.basename(folder)),
      lines.join("\n"),
    );
  }
  for (const channel of ["LuixBits", "Luix_OS"]) {
    const entries = [...topics.keys()].filter((key) =>
      key.startsWith(`youtube/${channel}/`),
    );
    const lines = [
      `* ${channel}`,
      "",
      link("youtube/index.norg", "YouTube overview"),
      "",
      ...entries
        .sort()
        .map(
          (folder) =>
            `- ${link(`${folder}/index.norg`, human(path.posix.basename(folder)))}`,
        ),
    ];
    write(`youtube/${channel}/index.norg`, channel, lines.join("\n"));
  }
  const sorted = [...productions.values()].sort((a, b) =>
    (documentById.get(a.id)?.title || a.title).localeCompare(
      documentById.get(b.id)?.title || b.title,
      undefined,
      { numeric: true },
    ),
  );
  const videos = sorted.filter(
    (p) => (documentById.get(p.id)?.kind || "video") === "video",
  );
  const active = videos.filter((p) =>
    ["planning", "in-progress"].includes(documentById.get(p.id)?.status),
  );
  active.sort(
    (a, b) =>
      Number(b.id === plan.priorityProduction) -
      Number(a.id === plan.priorityProduction),
  );
  const ideas = videos.filter((p) => documentById.get(p.id)?.status === "idea");
  const released = videos.filter(
    (p) => documentById.get(p.id)?.status === "done",
  );
  const trashed = videos.filter(
    (p) => documentById.get(p.id)?.status === "trashed",
  );
  const references = sorted.filter((p) =>
    ["guide", "reference"].includes(documentById.get(p.id)?.kind),
  );
  const page = (file, title, intro, entries, extra = []) =>
    write(
      file,
      title,
      [
        `* ${title}`,
        "",
        link("youtube/index.norg", "YouTube overview"),
        "",
        intro,
        "",
        documentLinks(entries),
        "",
        ...extra,
      ].join("\n"),
      { append: true },
    );
  page(
    "youtube/ideas/index.norg",
    "Video ideas",
    "Proposals and parked drafts. These are not active productions; selecting a topic means changing its status to Planning.",
    ideas,
    [
      "** Research only",
      "ThinkRail, Omarchy and REA remain research candidates.",
      link(
        "youtube/guides/channel-plan.norg",
        "Read the topic research and proposed calendar",
      ),
    ],
  );
  page(
    "youtube/released/index.norg",
    "Released videos",
    "Completed videos and shorts. Scheduled uploads appear on the overview until their release date. Supporting files stay with each video.",
    released,
  );
  page(
    "youtube/reference/index.norg",
    "Production reference",
    "Series ledgers and earlier versions are reference material, rather than additional open videos.",
    references,
    [
      "** Planning and workflow",
      link("youtube/guides/index.norg", "Guides and earlier notes"),
      "",
      "** Browse by channel",
      link(
        "youtube/LuixBits/index.norg",
        "LuixBits: Linux, NixOS, Neovim, AI and projects",
      ),
      link("youtube/Luix_OS/index.norg", "Luix_OS: Star Citizen"),
    ],
  );
  const scheduled = plan.events
    .filter(
      (event) =>
        event.kind === "release" &&
        event.status !== "done" &&
        (!today || event.date >= today),
    )
    .sort(
      (a, b) =>
        a.date.localeCompare(b.date) ||
        (a.time || "").localeCompare(b.time || ""),
    );
  const lines = [
    "* YouTube overview",
    "",
    link("index.norg", "Notes home"),
    "",
    "Move with j/k. Enter opens the link on this line. Backspace returns.",
    "",
    `** Active productions (${active.length})`,
    documentLinks(active) || "No open productions.",
    "",
    "Each video opens its Plan, Narration and My notes.",
    ...(scheduled.length
      ? [
          "",
          `** Scheduled uploads (${plan.timeZone})`,
          norgLinks(
            ["Video", "Date", "Time"],
            scheduled.map((event) => [
              link(eventPage(event), event.title),
              event.date,
              event.time || "—",
            ]),
          ),
        ]
      : []),
    "",
    "** Other indexes",
    norgLinks(
      ["Open", "Contents"],
      [
        [
          link("youtube/ideas/index.norg", `Ideas (${ideas.length})`),
          "Proposals and parked drafts",
        ],
        [
          link("youtube/released/index.norg", `Released (${released.length})`),
          "Completed videos and shorts",
        ],
        [
          link(
            "youtube/reference/index.norg",
            `Reference (${references.length})`,
          ),
          "Series plans, earlier versions and channel folders",
        ],
        [
          link("youtube/guides/schedule.norg", "Schedule"),
          "Confirmed releases and proposed topic slots",
        ],
      ],
    ),
    "",
  ];
  if (trashed.length)
    lines.push("** Trashed", ...trashed.map(documentLine), "");
  lines.push(
    "Index: Space n y i. Dashboard: Space n y d. Calendar: Space n j c. Journal: Space n j j.",
  );
  write("youtube/index.norg", "YouTube overview", lines.join("\n"), {
    append: true,
  });
}
