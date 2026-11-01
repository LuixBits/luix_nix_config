import { createHash } from "node:crypto";
import {
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";

const begin = "@comment\nluix-youtube:begin\n@end\n";
const end = "@comment\nluix-youtube:end\n@end";
const read = (file) => readFileSync(file, "utf8");
const hash = (value) => createHash("sha256").update(value).digest("hex");
const slash = (value) => value.split(path.sep).join("/");
const clean = (value) =>
  String(value)
    .replace(/[\r\n\[\]{}]/g, " ")
    .trim();
const human = (value) =>
  value
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .replace(/[-_]/g, " ")
    .replace(/^\w/, (first) => first.toUpperCase());
const label = (folder) => {
  const month = /^journal\/(\d{4})\/(\d{2})$/.exec(folder);
  if (month)
    return new Intl.DateTimeFormat("en", {
      month: "long",
      year: "numeric",
      timeZone: "UTC",
    }).format(new Date(month[1] + "-" + month[2] + "-01T12:00:00Z"));
  return (
    {
      "computer-science": "Computing",
      private: "Personal",
      japanese: "Japanese",
      journal: "Journal",
      templates: "Templates",
      work: "Work",
      meetings: "Meetings",
      presentations: "Presentations",
      research: "Research",
      archive: "Archive",
    }[folder] || human(path.posix.basename(folder))
  );
};
const link = (note, title) =>
  "{:$/" + note.replace(/\.norg$/, "") + ":}[" + clean(title) + "]";

function safe(root, relative) {
  if (path.isAbsolute(relative) || relative.split(/[\\/]/).includes(".."))
    throw new Error("Unsafe notes index path: " + relative);
  let file = root;
  for (const part of relative.split("/")) {
    file = path.join(file, part);
    try {
      if (lstatSync(file).isSymbolicLink())
        throw new Error("Refusing a symlink notes index: " + relative);
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
  }
  return file;
}

function atomic(file, content) {
  mkdirSync(path.dirname(file), { recursive: true });
  const temporary = file + "." + process.pid + ".tmp";
  try {
    writeFileSync(temporary, content, { mode: 0o600 });
    renameSync(temporary, file);
  } finally {
    rmSync(temporary, { force: true });
  }
}

export function workspaceIndexPath(folder) {
  // These directories belong to other plugins; indexes must not become cards,
  // templates or dated journal entries.
  return /^(journal|templates|japanese\/flashcards)(\/|$)/.test(folder)
    ? ".indexes/" + folder + ".norg"
    : folder + "/index.norg";
}

export function workspaceNotes(notesRoot) {
  if (!existsSync(notesRoot)) return [];
  const walk = (folder = "") =>
    readdirSync(path.join(notesRoot, folder), { withFileTypes: true }).flatMap(
      (entry) => {
        if (entry.name.startsWith(".") || entry.isSymbolicLink()) return [];
        const relative = path.posix.join(folder, entry.name);
        if (relative === "youtube" || relative === "indexes") return [];
        if (entry.isDirectory()) return walk(relative);
        if (
          !entry.isFile() ||
          !entry.name.endsWith(".norg") ||
          relative === "index.norg"
        )
          return [];
        const content = read(path.join(notesRoot, relative));
        if (entry.name === "index.norg" && content.includes(begin)) {
          const personal = content.replace(/@document\.meta[\s\S]*?@end/, "")
            .replace(/@comment\nluix-youtube:begin\n@end\n[\s\S]*?@comment\nluix-youtube:end\n@end/, "").trim();
          if (!personal) return [];
        }
        const declared = /^title:\s*(.+)$/m.exec(content)?.[1];
        const title =
          declared && !/[{}]/.test(declared)
            ? declared
            : human(entry.name.slice(0, -5));
        return [{ note: relative, title: clean(title) }];
      },
    );
  return walk().sort((a, b) =>
    a.note.localeCompare(b.note, undefined, { numeric: true }),
  );
}

// Titles and filenames change navigation; generated indexes and body edits do not.
export function workspaceIndexSignature(notesRoot) {
  return workspaceNotes(notesRoot)
    .map(({ note, title }) => note + ":" + title)
    .join("\n");
}

export function workspaceIndexPages({ notesRoot, today, archivedHome }) {
  const files = workspaceNotes(notesRoot);
  const pages = new Map();
  const indexPath = workspaceIndexPath;
  const categories = new Map();
  for (const item of files) {
    const folder = path.posix.dirname(item.note);
    if (folder === ".") continue;
    const root = folder.split("/")[0];
    if (!categories.has(root)) categories.set(root, label(root));
  }
  if (files.some((item) => item.note === "neovim.norg"))
    categories.set("computer-science", "Computing");
  if (files.some((item) => item.note === "llm-writing-research.norg"))
    categories.set("research", "Research");
  const folders = new Set();
  for (const item of files) {
    let folder = path.posix.dirname(item.note);
    while (folder !== ".") {
      folders.add(folder);
      folder = path.posix.dirname(folder);
    }
  }
  for (const category of categories.keys()) folders.add(category);
  const titleOf = (folder) =>
    folder.includes("/")
      ? label(folder)
      : categories.get(folder) || label(folder);
  for (const folder of [...folders].sort()) {
    const title = titleOf(folder);
    const parent = path.posix.dirname(folder);
    const body = [
      "** Browse " + title,
      "",
      link(
        parent === "." ? "index.norg" : indexPath(parent),
        parent === "." ? "Notes home" : titleOf(parent),
      ),
      "",
    ];
    if (folder === "journal") {
      body.push(
        link(
          "journal/" + today.replaceAll("-", "/") + ".norg",
          "Today's journal",
        ),
        "",
      );
      if (files.some((item) => item.note === "journal.norg"))
        body.push(link("journal.norg", "Neorg journal table of contents"), "");
    }
    const overviewFile = safe(notesRoot, indexPath(folder));
    const overviewText = existsSync(overviewFile) ? read(overviewFile)
      .replace(/@comment\nluix-youtube:begin\n@end\n[\s\S]*?@comment\nluix-youtube:end\n@end/, "") : "";
    const alreadyLinked = new Set([...overviewText.matchAll(/\{:\$\/([^:}]+):\}/g)].map((match) => match[1] + ".norg"));
    const children = [...folders].filter(
      (child) => path.posix.dirname(child) === folder && !alreadyLinked.has(indexPath(child)),
    );
    const direct = files.filter(
      (item) => path.posix.dirname(item.note) === folder,
    );
    if (folder === "computer-science")
      direct.push(...files.filter((item) => item.note === "neovim.norg"));
    if (folder === "research")
      direct.push(
        ...files.filter((item) => item.note === "llm-writing-research.norg"),
      );
    if (children.length)
      body.push(
        "*** Folders",
        ...children.map(
          (child) => "- " + link(indexPath(child), titleOf(child)),
        ),
        "",
      );
    const notes = direct.filter((item) => path.posix.basename(item.note) !== "index.norg" && !alreadyLinked.has(item.note));
    if (notes.length) {
      body.push(
        "*** Notes",
        ...notes.map((item) => {
          const date = /^journal\/(\d{4})\/(\d{2})\/(\d{2})\.norg$/.exec(
            item.note,
          );
          const title =
            item.note === archivedHome
              ? "Previous notes home (original content)"
              : date
                ? date.slice(1).join("-")
                : item.title;
          return "- " + link(item.note, title);
        }),
        "",
      );
    }
    if (!children.length && !notes.length && alreadyLinked.size) body.length = 0;
    pages.set(indexPath(folder), { title, body: body.join("\n") });
  }
  const loose = files.filter(
    (item) =>
      path.posix.dirname(item.note) === "." &&
      !["neovim.norg", "llm-writing-research.norg", "journal.norg"].includes(
        item.note,
      ),
  );
  if (loose.length) {
    categories.set("other", "Other notes");
    pages.set(indexPath("other"), {
      title: "Other notes",
      body: [
        "* Other notes",
        "",
        link("index.norg", "Notes home"),
        "",
        ...loose.map((item) => "- " + link(item.note, item.title)),
      ].join("\n"),
    });
  }
  const home = [
    "* Notes", "",
    "Move with j/k. Enter opens the link on this line. Backspace returns.", "",
    "** Areas", "",
    "- " + link("private/index.norg", "Private") + " — Personal notes, study and projects",
    "- " + link("work/index.norg", "Work") + " — Projects, meetings and presentations",
    "- " + link("youtube/index.norg", "YouTube") + " — Productions, scripts and releases",
    "", "** Daily and tools", "",
  ];
  for (const category of ["journal", "japanese", "templates"])
    if (categories.has(category)) home.push("- " + link(indexPath(category), label(category)));
  // A folder someone adds remains discoverable without taking over the main areas.
  const other = [...categories.keys()].filter((name) =>
    !["private", "work", "journal", "japanese", "templates"].includes(name));
  if (other.length) home.push("", "** Other folders", "",
    ...other.map((name) => "- " + link(indexPath(name), categories.get(name))));
  for (const area of ["private", "work"]) {
    if (!pages.has(indexPath(area))) pages.set(indexPath(area), {
      title: label(area), body: "* " + label(area) + "\n\n" + link("index.norg", "Notes home"),
    });
  }
  home.push("", "Find notes: Space n f. Notes home: Space n i. YouTube: Space n y i.");
  pages.set("index.norg", { title: "Notes", body: home.join("\n") });
  return pages;
}

export function syncWorkspaceIndexes({ notesRoot, today, state, write }) {
  if (state.notesHomeVersion !== 1) return false;
  const pages = workspaceIndexPages({
    notesRoot,
    today,
    archivedHome: state.previousNotesHome,
  });
  for (const [note, { title, body }] of pages)
    write(note, title, body, {
      append: true,
      category: "notes",
      scope: "notes",
    });
  for (const note of state.workspaceIndexFiles || []) {
    if (!pages.has(note) && !note.startsWith("indexes/"))
      write(
        note,
        human(path.posix.basename(note, ".norg")),
        "* Index\n\n" +
          link("index.norg", "Notes home") +
          "\n\nNo notes are currently indexed here.",
        { append: true, category: "notes", scope: "notes" },
      );
  }
  state.workspaceIndexFiles = [...pages.keys()];
  return true;
}

// Called only by the explicitly requested organize-notes command, under the sync lock.
export function organizeNotesHome({ repoRoot, notesRoot, today }) {
  const work = path.join(repoRoot, "private/work/youtube-notes");
  const stateFile = path.join(work, "state.json");
  const state = existsSync(stateFile)
    ? JSON.parse(read(stateFile))
    : { version: 1, notesRoot, files: {}, journalDates: [] };
  if (state.notesRoot !== notesRoot)
    throw new Error(
      "The notes destination differs from the existing sync state",
    );
  if (state.notesHomeVersion === 1) return { alreadyOrganized: true };
  const root = safe(notesRoot, "index.norg");
  const original = existsSync(root) ? read(root) : "";
  const backup = path.join(
    work,
    "home-migrations",
    new Date().toISOString().replace(/[:.]/g, "-"),
  );
  mkdirSync(backup, { recursive: true });
  atomic(
    path.join(backup, "previous-state.json"),
    JSON.stringify(state, null, 2) + "\n",
  );
  atomic(path.join(backup, "original-index.norg"), original);
  let archive;
  if (original) {
    let version = 1;
    do {
      archive =
        "private/archive/previous-home" +
        (version === 1 ? "" : "-" + version) +
        ".norg";
      version++;
    } while (existsSync(path.join(notesRoot, archive)));
    const target = safe(notesRoot, archive);
    atomic(target, original);
    if (hash(read(target)) !== hash(original))
      throw new Error("Previous notes home backup did not verify");
  }
  const home = workspaceIndexPages({
    notesRoot,
    today,
    archivedHome: archive,
  }).get("index.norg");
  const managed = home.body.trim() + "\n";
  const content =
    "@document.meta\ntitle: Notes\nauthors: Luix\ncategories: notes\n@end\n\n" +
    begin +
    managed +
    end +
    "\n";
  if (existsSync(root) && read(root) !== original)
    throw new Error(
      "Notes home changed during organization; original saved without replacing the current note",
    );
  atomic(root, content);
  // Old YouTube-only writers must refuse to replace the new shared home.
  delete state.files["index.norg"];
  state.notesIndexHashes = {
    ...state.notesIndexHashes,
    "index.norg": hash(managed),
  };
  state.notesHomeVersion = 1;
  if (archive) state.previousNotesHome = archive;
  atomic(stateFile, JSON.stringify(state, null, 2) + "\n");
  atomic(
    path.join(backup, "receipt.json"),
    JSON.stringify(
      {
        notesRoot,
        archive,
        originalSha256: hash(original),
        replacementSha256: hash(content),
        complete: true,
      },
      null,
      2,
    ) + "\n",
  );
  return {
    archived: archive || null,
    receipt: slash(path.relative(repoRoot, path.join(backup, "receipt.json"))),
  };
}
