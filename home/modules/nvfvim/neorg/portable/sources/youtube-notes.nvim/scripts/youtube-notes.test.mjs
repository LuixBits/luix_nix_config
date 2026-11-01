import { metadataPath as sharedMetadataPath, readData as readSharedData } from "./youtube-workspace.mjs";
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import {
  existsSync,
  cpSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  realpathSync,
  rmSync,
  symlinkSync,
  writeFileSync,
  utimesSync,
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import {
  catalog,
  exportWorkspace,
  dashboardData,
  installNeovim,
  markdownToNorg,
  monthCalendar,
  syncNotes,
  updateEvent,
  updateDocument,
  validDate,
  scheduleRelease,
} from "./youtube-notes.mjs";
import { location, organizeExisting } from "./youtube-notes-structure.mjs";
import { projectRecords } from "./youtube-documents.mjs";
import { organizeNotesHome, workspaceIndexPages } from "./notes-index.mjs";
import { norgTable } from "./norg-table.mjs";

const read = (file) => readFileSync(file, "utf8");
const cli = fileURLToPath(new URL("./youtube-notes.mjs", import.meta.url));
const chapter =
  "<!-- title: A useful example -->\n\nHello nerds. This command finds the setting.\n";

function fixture(t) {
  const root = mkdtempSync(path.join(tmpdir(), "luixbits-notes-test-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const repoRoot = path.join(root, "checkout");
  const notesRoot = path.join(root, "notes");
  const put = (relative, text) => {
    const file = path.join(repoRoot, relative);
    mkdirSync(path.dirname(file), { recursive: true });
    writeFileSync(file, text);
  };
  const putNote = (relative, text) => {
    const file = path.join(notesRoot, relative);
    mkdirSync(path.dirname(file), { recursive: true });
    writeFileSync(file, text);
  };
  put(
    "docs/video-scripts/sample/sample.md",
    "# A useful plan\n\n[Chapter](sample-chapter01.md)\n\n| Choice | Result |\n| --- | --- |\n| Read | Inspect it |\n",
  );
  put("docs/video-scripts/sample/sample-chapter01.md", chapter);
  put(
    "docs/video-scripts/sample/index.md",
    "# Existing index source\n\nThis is source content.\n",
  );
  put(
    "docs/video-scripts/one-short.md",
    "<!-- title: One short -->\n\nHello nerds. One small task.\n",
  );
  put("docs/video-ideas.md", "# Our video ideas\n\nThe agreed plan.\n");
  put("private/raw-take.md", "Never export this private diagnostic.\n");
  put(
    "config/youtube-plan.json",
    JSON.stringify({
      version: 1,
      timeZone: "Europe/Zurich",
      priorityProduction: "sample",
      completedProductions: [],
      events: [
        {
          id: "sample-release",
          date: "2026-10-29",
          production: "sample",
          channel: "LuixBits",
          title: "Sample",
          status: "planned",
        },
        {
          id: "sc-slot",
          date: "2026-10-31",
          channel: "Luix_OS",
          title: "Star Citizen",
          status: "planned",
        },
      ],
    }),
  );
  putNote("index.norg", "* My existing home\n\nKeep this exactly.\n");
  put(
    "config/youtube-documents.json",
    JSON.stringify({
      version: 1,
      items: {
        sample: { status: "planning" },
        "one-short": { status: "done" },
      },
    }),
  );
  putNote(
    "youtube/index.norg",
    "* My existing YouTube notes\n\nKeep my ideas.\n",
  );
  putNote("journal/2026/10/29.norg", "* Thursday\n\nPersonal journal text.\n");
  const options = { repoRoot, notesRoot, today: "2026-10-29" };
  return {
    root,
    repoRoot,
    notesRoot,
    put,
    putNote,
    options,
    sync: () => syncNotes(options),
    note: (relative) => read(path.join(notesRoot, relative)),
  };
}

test("a second device needs only synced notes for dashboard, statuses and journal actions", (t) => {
  const f = fixture(t);
  f.sync();
  organizeNotesHome(f.options);
  f.sync();
  exportWorkspace(f.options);
  const laptop = path.join(f.root, "another-user/notes");
  cpSync(f.notesRoot, laptop, { recursive: true, verbatimSymlinks: true });
  const replica = { repoRoot: laptop, notesRoot: laptop, today: "2026-10-29" };
  assert.deepEqual(syncNotes(replica).conflicts, []);
  const remote = dashboardData(replica), local = dashboardData(f.options);
  assert.deepEqual(remote.documents.items.filter(x => x.kind === "video").map(x => [x.id, x.status, x.words, x.updated]), local.documents.items.filter(x => x.kind === "video").map(x => [x.id, x.status, x.words, x.updated]));
  assert.match(read(path.join(laptop, "youtube/LuixBits/projects/sample/index.norg")), /This command finds the setting/);
  updateDocument(laptop, "sample", "done", { notesRoot: laptop });
  updateEvent(laptop, "sc-slot", { date: "2026-11-04" });
  assert.deepEqual(syncNotes(replica).conflicts, []);
  assert.match(read(path.join(laptop, "journal/2026/11/04.norg")), /youtube-task: sc-slot/);
  assert.doesNotMatch(read(path.join(laptop, "journal/2026/10/31.norg")), /youtube-task: sc-slot/);
  assert.match(read(path.join(laptop, "youtube/LuixBits/projects/sample/index.norg")), /Status: Done/);
  // Simulate notes Git sync back to the publisher. Its next source export must
  // honor the laptop's changes instead of restoring old checkout metadata.
  cpSync(laptop, f.notesRoot, { recursive: true, verbatimSymlinks: true });
  assert.deepEqual(f.sync().conflicts, []);
  assert.equal(dashboardData(f.options).documents.items.find(x => x.id === "sample").status, "done");
  assert.equal(dashboardData(f.options).events.find(x => x.id === "sc-slot").date, "2026-11-04");
  assert.ok(f.note("journal/2026/10/29.norg").startsWith("* Thursday\n\nPersonal journal text.\n"));
  const snapshot = f.note("youtube/.state/catalog.norg");
  assert.ok(!snapshot.includes(f.repoRoot) && !snapshot.includes(chapter), "Shared catalog includes machine paths or duplicate narration");
  assert.throws(() => exportWorkspace(f.options), /already uses a shared/);
});

test("replicas preserve edited generated text without claiming its ownership", (t) => {
  const f = fixture(t);
  f.sync();
  exportWorkspace(f.options);
  const replica = { repoRoot: f.notesRoot, notesRoot: f.notesRoot, today: "2026-10-29" };
  const note = "youtube/LuixBits/projects/sample/index.norg";
  f.putNote(note, f.note(note).replace("This command finds the setting.", "My protected rewrite."));
  const before = f.note("youtube/.state/ownership.norg");
  const result = syncNotes(replica);
  assert.ok(result.conflicts.includes(note));
  assert.match(f.note(note), /My protected rewrite/);
  assert.equal(f.note("youtube/.state/ownership.norg"), before);
  assert.ok(f.sync().conflicts.includes(note));
  assert.match(f.note(note), /My protected rewrite/);
});

test("YouTube and Star Citizen are subsections in the normal journal, with personal text preserved", (t) => {
  const f = fixture(t);
  f.sync();
  const personal = f.note("journal/2026/10/29.norg");
  assert.ok(personal.startsWith("* Thursday\n\nPersonal journal text.\n"));
  assert.match(personal, /^\*\* YouTube$/m);
  assert.doesNotMatch(personal, /^\* YouTube$/m);
  const sc = f.note("journal/2026/10/31.norg");
  assert.match(sc, /^categories: journal$/m);
  assert.match(sc, /^\* 2026-10-31$/m);
  assert.match(sc, /^\*\* YouTube$/m);
  assert.match(sc, /^\*\*\* Star Citizen$/m);
  const again = f.sync();
  assert.deepEqual(again.conflicts, []);
  assert.equal(f.note("journal/2026/10/31.norg"), sc);
});

test("exports plans and ordered narration as Norg, preserves indexes/journals and leaves sources untouched", (t) => {
  const f = fixture(t);
  const result = f.sync();
  assert.equal(result.scripts, 2);
  assert.deepEqual(result.conflicts, []);
  assert.equal(
    read(
      path.join(f.repoRoot, "docs/video-scripts/sample/sample-chapter01.md"),
    ),
    chapter,
  );
  assert.ok(
    f
      .note("index.norg")
      .startsWith("* My existing home\n\nKeep this exactly.\n"),
  );
  assert.ok(
    f
      .note("youtube/index.norg")
      .startsWith("* My existing YouTube notes\n\nKeep my ideas.\n"),
  );
  assert.ok(
    f
      .note("journal/2026/10/29.norg")
      .startsWith("* Thursday\n\nPersonal journal text.\n"),
  );
  assert.match(
    f.note("youtube/LuixBits/projects/sample/planning/sample.norg"),
    /\{:.*sample\/narration\/sample-chapter01:\}\[Chapter\]/,
  );
  assert.match(
    f.note("youtube/LuixBits/projects/sample/planning/sample.norg"),
    /- Choice: Read; Result: Inspect it/,
  );
  assert.match(
    f.note("youtube/LuixBits/projects/sample/planning/source-index.norg"),
    /This is source content/,
  );
  assert.match(
    f.note("youtube/LuixBits/projects/sample/index.norg"),
    /\* Plan\n/,
  );
  assert.match(
    f.note("youtube/LuixBits/projects/sample/index.norg"),
    /\* Narration\n/,
  );
  assert.match(
    f.note("youtube/LuixBits/projects/sample/index.norg"),
    /Hello nerds\. This command/,
  );
  assert.match(
    f.note("youtube/LuixBits/projects/sample/index.norg"),
    /Choice: Read; Result: Inspect it/,
  );
  assert.match(
    f.note("youtube/LuixBits/projects/sample/narration/sample-chapter01.norg"),
    /Hello nerds\. This command/,
  );
  assert.doesNotMatch(
    f.note("youtube/LuixBits/projects/sample/narration/sample-chapter01.norg"),
    /<!-- title:/,
  );
  assert.match(
    f.note("journal/2026/10/29.norg"),
    /youtube\/LuixBits\/projects\/sample\/index/,
  );
  assert.match(
    f.note("youtube/Luix_OS/star-citizen/planned-slots/sc-slot.norg"),
    /video has not been chosen/,
  );
  assert.equal(
    existsSync(path.join(f.notesRoot, "youtube/videos/raw-take")),
    false,
  );
});

test("repeated sync is idempotent and source changes preserve personal additions", (t) => {
  const f = fixture(t);
  f.sync();
  assert.equal(f.sync().updated, 0);
  const note = "youtube/LuixBits/projects/sample/planning/sample.norg";
  f.putNote(note, f.note(note) + "A personal follow-up that stays.\n");
  f.put(
    "docs/video-scripts/sample/sample.md",
    "# A useful plan\n\nUpdated canonical explanation.\n",
  );
  const result = f.sync();
  assert.deepEqual(result.conflicts, []);
  assert.match(f.note(note), /Updated canonical explanation/);
  assert.match(f.note(note), /A personal follow-up that stays/);
});

test("edited generated content is kept intact and reported as a conflict", (t) => {
  const f = fixture(t);
  f.sync();
  const note = "youtube/LuixBits/projects/sample/planning/sample.norg";
  const edited = f
    .note(note)
    .replace("\n* A useful plan\n", "\n* My own edited plan\n");
  f.putNote(note, edited);
  f.put("docs/video-scripts/sample/sample.md", "# Replacement from source\n");
  assert.ok(f.sync().conflicts.includes(note));
  assert.equal(f.note(note), edited);
});

test("one video page collects current chapters in order and keeps personal feedback", (t) => {
  const f = fixture(t);
  f.put(
    "docs/video-scripts/sample/sample-chapter10.md",
    "<!-- title: Tenth chapter -->\n\nTenth chapter words.\n",
  );
  f.put(
    "docs/video-scripts/sample/sample-chapter02.md",
    "<!-- title: Second chapter -->\n\nSecond chapter words.\n",
  );
  f.put(
    "docs/video-scripts/sample/sample-opening-proof.md",
    "<!-- title: Old guide -->\n\nTemporary guide that must not become current narration.\n",
  );
  f.sync();
  const file = "youtube/LuixBits/projects/sample/index.norg";
  const narration = f
    .note(file)
    .split("\n* Narration\n")[1]
    .split("\n* Reference material\n")[0];
  assert.ok(
    narration.indexOf("Second chapter words.") <
      narration.indexOf("Tenth chapter words."),
  );
  assert.doesNotMatch(narration, /Temporary guide/);
  assert.match(f.note(file), /\{\* Plan\}\[Plan\]/);
  f.putNote(file, f.note(file) + "My feedback on this video.\n");
  f.put(
    "docs/video-scripts/sample/sample-chapter03.md",
    "<!-- title: Third chapter -->\n\nNew narration belongs in the same page.\n",
  );
  assert.deepEqual(f.sync().conflicts, []);
  assert.match(f.note(file), /New narration belongs in the same page/);
  assert.match(f.note(file), /My feedback on this video/);
});

test("moving and completing an event updates old/new journals without touching personal text", (t) => {
  const f = fixture(t);
  f.sync();
  updateEvent(f.repoRoot, "sample-release", {
    date: "2026-11-03",
    status: "done",
  });
  f.sync();
  const old = f.note("journal/2026/10/29.norg");
  assert.match(old, /Personal journal text/);
  assert.doesNotMatch(old, /youtube-task: sample-release/);
  assert.match(f.note("journal/2026/11/03.norg"), /LuixBits · Done/);
  assert.match(f.note("journal/2026/11/03.norg"), /\[Options\]/);
  assert.match(f.note("youtube/guides/schedule.norg"), /\*\* 2026-11-03/);
  assert.doesNotMatch(f.note("youtube/index.norg"), /- \(x\) LuixBits:/);
});

test("rejects invalid dates, duplicate IDs and unknown assignments without changing the schedule", (t) => {
  const f = fixture(t);
  const before = read(path.join(f.repoRoot, "config/youtube-plan.json"));
  assert.throws(
    () => updateEvent(f.repoRoot, "sample-release", { date: "2026-02-30" }),
    /Invalid date/,
  );
  assert.throws(
    () => updateEvent(f.repoRoot, "sample-release", { production: "missing" }),
    /existing canonical/,
  );
  assert.throws(
    () => updateEvent(f.repoRoot, "sample-release", { status: "published" }),
    /Status/,
  );
  assert.equal(read(path.join(f.repoRoot, "config/youtube-plan.json")), before);
  const plan = JSON.parse(before);
  plan.events.push(plan.events[0]);
  f.put("config/youtube-plan.json", JSON.stringify(plan));
  assert.throws(f.sync, /duplicate event ID/);
});

test("calendar handles leap days and links each real day to a nested journal", () => {
  const calendar = monthCalendar("2028-02", [
    { date: "2028-02-29", status: "planned" },
  ]);
  assert.match(calendar, /journal\/2028\/02\/29:\}\[29\+\]/);
  assert.doesNotMatch(calendar, /\/02\/30/);
  assert.equal((calendar.match(/\{:.*?:\}\[/g) || []).length, 29);
  assert.throws(() => validDate("2026-02-29"), /Invalid date/);
  assert.equal(validDate("2028-02-29"), "2028-02-29");
});

test("dashboard overview separates overdue tasks and completed priority without changing the plan", (t) => {
  const f = fixture(t);
  const before = read(path.join(f.repoRoot, "config/youtube-plan.json"));
  const data = dashboardData({
    repoRoot: f.repoRoot,
    notesRoot: f.notesRoot,
    today: "2026-10-30",
  });
  assert.deepEqual(data.counts, { today: 0, overdue: 1, upcoming: 1, done: 0 });
  assert.equal(data.priority.id, "sample");
  assert.equal(read(path.join(f.repoRoot, "config/youtube-plan.json")), before);
  updateEvent(f.repoRoot, "sample-release", { status: "done" });
  const complete = dashboardData({
    repoRoot: f.repoRoot,
    notesRoot: f.notesRoot,
    today: "2026-10-30",
  });
  assert.equal(complete.priority, null);
  assert.equal(complete.counts.overdue, 0);
  assert.equal(complete.counts.done, 1);
});

test("dashboard keeps complete Monday–Sunday weeks, empty days and completed work across boundaries", (t) => {
  const f = fixture(t);
  updateEvent(f.repoRoot, "sample-release", { status: "done" });
  for (const [today, first, last] of [
    ["2026-10-29", "2026-10-26", "2026-11-08"],
    ["2026-11-01", "2026-10-26", "2026-11-08"],
    ["2026-11-02", "2026-11-02", "2026-11-15"],
    ["2026-12-31", "2026-12-28", "2027-01-10"],
    ["2027-03-28", "2027-03-22", "2027-04-04"],
  ]) {
    const data = dashboardData({
      repoRoot: f.repoRoot,
      notesRoot: f.notesRoot,
      today,
    });
    const days = data.weeks.flatMap((week) => week.days);
    assert.equal(days.length, 14);
    assert.equal(new Set(days.map((day) => day.date)).size, 14);
    assert.equal(days[0].date, first);
    assert.equal(days.at(-1).date, last);
    assert.ok(days.some((day) => day.events.length === 0));
    assert.equal(data.weeks[0].days.length, 7);
    assert.equal(data.weeks[1].days.length, 7);
  }
  const data = dashboardData({
    repoRoot: f.repoRoot,
    notesRoot: f.notesRoot,
    today: "2026-10-29",
  });
  assert.equal(data.tomorrow, "2026-10-30");
  assert.equal(data.weeks[0].days[3].events[0].status, "done");
});

test("legacy chapters belong to one video and each content folder has a linked index", (t) => {
  const f = fixture(t);
  f.put("docs/video-scripts/roomplan-chapter02.md", "Second spoken chapter.\n");
  f.put("docs/video-scripts/roomplan-chapter01.md", "First spoken chapter.\n");
  const { productions } = catalog(f.repoRoot);
  assert.ok(productions.has("roomplan"));
  assert.ok(!productions.has("roomplan-chapter01"));
  assert.ok(productions.get("roomplan").files.every((file) => file.spoken));
  f.sync();
  const page = f.note(location("roomplan").note);
  assert.ok(
    page.indexOf("First spoken chapter.") <
      page.indexOf("Second spoken chapter."),
  );
  assert.match(f.note("youtube/index.norg"), /YouTube overview/);
  assert.match(f.note("youtube/LuixBits/index.norg"), /neovim\/index/);
  assert.match(f.note("youtube/LuixBits/neovim/index.norg"), /roomplan\/index/);
  assert.match(
    f.note("youtube/LuixBits/neovim/roomplan/narration/index.norg"),
    /roomplan-chapter01/,
  );
  const walk = (directory) =>
    readdirSync(directory, { withFileTypes: true }).flatMap((entry) =>
      entry.isDirectory()
        ? walk(path.join(directory, entry.name))
        : entry.name.endsWith(".norg")
          ? [path.join(directory, entry.name)]
          : [],
    );
  for (const file of walk(path.join(f.notesRoot, "youtube"))) {
    for (const [, target] of read(file).matchAll(/\{:[$]\/([^:}]+):\}/g))
      assert.ok(
        existsSync(path.join(f.notesRoot, target + ".norg")),
        "Broken link " + target + " in " + file,
      );
  }
});

test("organization preserves personal writing, moves chapters together and keeps old links working", (t) => {
  const f = fixture(t);
  const digest = (value) => createHash("sha256").update(value).digest("hex");
  const oldBody = "* Old combined page\n";
  const oldPage =
    "@comment\nluix-youtube:begin\n@end\n" +
    oldBody +
    "@comment\nluix-youtube:end\n@end\n\n* My notes\nKeep this personal feedback.\n{:planning/sample:}[My old plan link]\n";
  f.putNote("youtube/videos/sample/index.norg", oldPage);
  f.putNote(
    "youtube/videos/sample/planning/sample.norg",
    "@comment\nluix-youtube:begin\n@end\n* Earlier plan\n@comment\nluix-youtube:end\n@end\n\nMy plan feedback.\n",
  );
  f.putNote("youtube/videos/sample/plan.norg", "* Old plan export\n");
  f.putNote("youtube/videos/sample/narration.norg", "* Old narration export\n");
  f.putNote(
    "youtube/videos/roomplan-chapter01/index.norg",
    "* My earlier chapter notes\n",
  );
  f.putNote(
    "youtube/RoomplanScript.norg",
    "* Personal Roomplan script\n{:roomplan-nvim-outline:}[Outline]\n",
  );
  f.putNote("youtube/roomplan-nvim-outline.norg", "* My Roomplan outline\n");
  f.put(
    "docs/video-scripts/roomplan-chapter01.md",
    "The real first chapter.\n",
  );
  f.put(
    "private/work/youtube-notes/state.json",
    JSON.stringify({
      version: 1,
      notesRoot: f.notesRoot,
      journalDates: [],
      files: {
        "youtube/videos/sample/index.norg": digest(oldBody),
        "youtube/videos/sample/planning/sample.norg":
          digest("* Earlier plan\n"),
      },
    }),
  );
  const plan = JSON.parse(
    read(path.join(f.repoRoot, "config/youtube-plan.json")),
  );
  const result = organizeExisting({ ...f.options, plan });
  assert.ok(result.moved > 0);
  const sample = location("sample").folder;
  assert.equal(
    realpathSync(path.join(f.notesRoot, "youtube/videos/sample/index.norg")),
    realpathSync(path.join(f.notesRoot, sample, "index.norg")),
  );
  for (const file of ["plan.norg", "narration.norg"])
    assert.equal(
      realpathSync(path.join(f.notesRoot, "youtube/videos/sample", file)),
      realpathSync(
        path.join(f.notesRoot, sample, "references/earlier-exports", file),
      ),
    );
  assert.match(
    f.note(sample + "/index.norg"),
    /\{:[$]\/youtube\/LuixBits\/projects\/sample\/planning\/sample:\}\[My old plan link\]/,
  );
  assert.match(
    f.note("youtube/LuixBits/neovim/roomplan/notes/RoomplanScript.norg"),
    /roomplan\/notes\/roomplan-nvim-outline/,
  );
  const receipt = JSON.parse(read(path.join(f.repoRoot, result.receipt)));
  assert.ok(receipt.complete);
  for (const file of receipt.files)
    assert.equal(
      digest(
        read(
          path.join(
            path.dirname(path.join(f.repoRoot, result.receipt)),
            "originals",
            file.from,
          ),
        ),
      ),
      file.sha256,
    );
  assert.equal(
    f.note("youtube/guides/earlier-overview.norg"),
    "* My existing YouTube notes\n\nKeep my ideas.\n",
  );
  assert.deepEqual(f.sync().conflicts, []);
  assert.match(f.note(sample + "/index.norg"), /Keep this personal feedback/);
  assert.match(
    f.note(
      "youtube/LuixBits/neovim/roomplan/references/earlier-pages/roomplan-chapter01/index.norg",
    ),
    /My earlier chapter notes/,
  );
  assert.match(
    f.note("youtube/LuixBits/neovim/roomplan/index.norg"),
    /Personal and earlier notes/,
  );
  assert.deepEqual(organizeExisting({ ...f.options, plan }), {
    moved: 0,
    alreadyOrganized: true,
  });
  assert.equal(f.sync().updated, 0);
});

test("already-organized notes move older spoken chapters into narration without losing feedback", (t) => {
  const f = fixture(t);
  const source = "docs/video-scripts/old-demo/old-demo-chapter01.md";
  f.put(source, "Spoken words from an earlier script.\n");
  const old =
    "youtube/LuixBits/projects/old-demo/planning/old-demo-chapter01.norg";
  const body =
    "Source: " +
    String.fromCharCode(96) +
    source +
    String.fromCharCode(96) +
    ".\n\nEarlier export.\n";
  f.putNote(
    old,
    "@comment\nluix-youtube:begin\n@end\n" +
      body +
      "@comment\nluix-youtube:end\n@end\n\nKeep my chapter feedback.\n",
  );
  f.put(
    "private/work/youtube-notes/state.json",
    JSON.stringify({
      version: 1,
      organizationVersion: 1,
      notesRoot: f.notesRoot,
      journalDates: [],
      files: { [old]: createHash("sha256").update(body).digest("hex") },
    }),
  );
  const sourceFiles = catalog(f.repoRoot).files;
  const next = sourceFiles.get(source).note;
  assert.match(next, /\/narration\//);
  const plan = JSON.parse(
    read(path.join(f.repoRoot, "config/youtube-plan.json")),
  );
  const result = organizeExisting({ ...f.options, plan, sourceFiles });
  assert.equal(result.moved, 1);
  assert.equal(
    realpathSync(path.join(f.notesRoot, old)),
    realpathSync(path.join(f.notesRoot, next)),
  );
  assert.deepEqual(f.sync().conflicts, []);
  assert.match(f.note(next), /Spoken words from an earlier script/);
  assert.match(f.note(next), /Keep my chapter feedback/);
  assert.match(
    f.note(location("old-demo").note),
    /Spoken words from an earlier script/,
  );
  assert.deepEqual(organizeExisting({ ...f.options, plan, sourceFiles }), {
    moved: 0,
    alreadyOrganized: true,
  });
});

test("organization refuses destination collisions before moving notes", (t) => {
  const f = fixture(t);
  f.putNote("youtube/videos/sample/index.norg", "* Original\n");
  f.putNote(location("sample").note, "* Existing destination\n");
  const plan = JSON.parse(
    read(path.join(f.repoRoot, "config/youtube-plan.json")),
  );
  assert.throws(
    () => organizeExisting({ ...f.options, plan }),
    /destination already exists/,
  );
  assert.equal(f.note("youtube/videos/sample/index.norg"), "* Original\n");
  assert.equal(f.note(location("sample").note), "* Existing destination\n");
  assert.equal(
    f.note("youtube/index.norg"),
    "* My existing YouTube notes\n\nKeep my ideas.\n",
  );
});

test("document registry covers every video, source plan, script and personal note with independent statuses", (t) => {
  const f = fixture(t);
  f.putNote(
    "youtube/guides/research.norg",
    "* My research\n\nKeep my working ideas.\n",
  );
  f.sync();
  const registry = () => dashboardData(f.options).documents;
  const initial = registry();
  assert.equal(initial.projects, 2);
  assert.ok(initial.items.find((item) => item.id === "sample").plans >= 1);
  assert.equal(initial.items.find((item) => item.id === "sample").scripts, 1);
  assert.equal(
    initial.items.find(
      (item) =>
        item.note === "youtube/LuixBits/projects/sample/narration/index.norg",
    ).scripts,
    1,
  );
  assert.ok(initial.items.some((item) => item.kind === "plan"));
  assert.ok(initial.items.some((item) => item.kind === "script"));
  assert.ok(
    initial.items.some(
      (item) => item.id === "note:youtube/guides/research.norg",
    ),
  );
  assert.equal(
    new Set(initial.items.map((item) => item.note)).size,
    initial.items.length,
  );
  const schedule = read(path.join(f.repoRoot, "config/youtube-plan.json"));
  const original = read(
    path.join(f.repoRoot, "docs/video-scripts/sample/sample-chapter01.md"),
  );
  for (const status of ["idea", "in-progress", "done", "trashed", "planning"]) {
    updateDocument(f.repoRoot, "sample", status, f.options);
    assert.deepEqual(f.sync().conflicts, []);
    const data = registry();
    assert.equal(
      data.items.find((item) => item.id === "sample").status,
      status,
    );
    assert.equal(
      data.items.find((item) =>
        item.note.endsWith("/narration/sample-chapter01.norg"),
      ).status,
      status,
    );
    assert.ok(existsSync(path.join(f.notesRoot, location("sample").note)));
    assert.match(f.note("youtube/index.norg"), /Active productions/);
    assert.equal(
      read(path.join(f.repoRoot, "config/youtube-plan.json")),
      schedule,
    );
    assert.equal(
      read(
        path.join(f.repoRoot, "docs/video-scripts/sample/sample-chapter01.md"),
      ),
      original,
    );
    assert.equal(
      f.note("youtube/guides/research.norg"),
      "* My research\n\nKeep my working ideas.\n",
    );
  }
  updateEvent(f.repoRoot, "sample-release", { status: "done" });
  assert.equal(
    registry().items.find((item) => item.id === "sample").status,
    "planning",
  );
});

test("source update dates survive sync and script tags can override their video's status", (t) => {
  const f = fixture(t);
  const stamp = new Date("2020-04-02T12:00:00Z");
  for (const file of catalog(f.repoRoot).productions.get("sample").files)
    utimesSync(file.absolute, stamp, stamp);
  f.sync();
  const script =
    "youtube/LuixBits/projects/sample/narration/sample-chapter01.norg";
  let data = dashboardData(f.options).documents;
  assert.equal(
    data.items.find((item) => item.id === "sample").updated,
    "2020-04-02",
  );
  assert.equal(data.items.find((item) => item.note === script).inherited, true);
  updateDocument(f.repoRoot, "sample", "in-progress", f.options);
  updateDocument(f.repoRoot, "note:" + script, "done", f.options);
  f.sync();
  data = dashboardData(f.options).documents;
  assert.equal(
    data.items.find((item) => item.id === "sample").status,
    "in-progress",
  );
  assert.equal(data.items.find((item) => item.note === script).status, "done");
  assert.equal(
    data.items.find((item) => item.note === script).inherited,
    false,
  );
  assert.equal(
    data.items.find((item) => item.note === script).updated,
    "2020-04-02",
  );
  assert.match(f.note(script), /Status: Done/);
  assert.match(f.note(script), /\[Change status\]/);
  assert.equal(f.sync().updated, 0);
  const before = read(path.join(f.repoRoot, "config/youtube-documents.json"));
  assert.throws(
    () => updateDocument(f.repoRoot, "missing", "done", f.options),
    /Unknown document/,
  );
  assert.throws(
    () => updateDocument(f.repoRoot, "sample", "published", f.options),
    /Document status/,
  );
  assert.equal(
    read(path.join(f.repoRoot, "config/youtube-documents.json")),
    before,
  );
});

test("curated registry keeps the three remaining productions open after the November 1 upload review", () => {
  const repoRoot = path.resolve(path.dirname(cli), "..");
  const plan = readSharedData(sharedMetadataPath(repoRoot, "plan"));
  const records = projectRecords({
    repoRoot,
    productions: catalog(repoRoot).productions,
    plan,
  });
  const active = records.filter(
    (item) =>
      item.kind === "video" &&
      ["planning", "in-progress"].includes(item.status),
  );
  assert.deepEqual(
    active.map((item) => item.id).sort(),
    ["nixos-one-year", "ryoku-nixos", "star-citizen-banu-merchantman"].sort(),
  );
  assert.ok(
    records
      .filter((item) => /^(daily-nixos-day|gaming-short-)/.test(item.id))
      .every((item) => item.status === "done"),
  );
  assert.ok(
    records
      .filter((item) => item.id.startsWith("spatial-input-part"))
      .every((item) => item.status === "idea"),
  );
  assert.equal(
    records.find((item) => item.id === "one-command-series-plan").kind,
    "guide",
  );
  assert.equal(
    records.find((item) => item.id === "openclaw-nixos-v3").kind,
    "reference",
  );
  assert.equal(
    records.find((item) => item.id === "nix-develop").status,
    "done",
  );
  assert.ok(
    !plan.events.some(
      (event) => event.production === "nix-develop" && event.status !== "done",
    ),
  );
});

test("line indexes keep links, scheduled uploads and personal notes through repeated sync", (t) => {
  const f = fixture(t);
  const plan = JSON.parse(
    read(path.join(f.repoRoot, "config/youtube-plan.json")),
  );
  plan.events[0].id = "sample-work";
  f.put("config/youtube-plan.json", JSON.stringify(plan));
  f.sync();
  organizeNotesHome(f.options);
  f.sync();
  assert.match(f.note("index.norg"), /- \{:\$\/work\/index:\}\[Work\]/);
  assert.doesNotMatch(f.note("youtube/index.norg"), /^: A1/m);
  assert.match(
    f.note("youtube/index.norg"),
    /- \{:\$\/youtube\/LuixBits\/projects\/sample\/index:\}\[A useful plan\]/,
  );
  updateDocument(f.repoRoot, "sample", "done", f.options);
  scheduleRelease(f.repoRoot, "sample", "2026-11-02", "14:30");
  scheduleRelease(f.repoRoot, "sample", "2026-11-03", "14:30");
  f.sync();
  const overview = f.note("youtube/index.norg");
  assert.match(overview, /Active productions \(0\)/);
  assert.match(overview, /Scheduled uploads \(Europe\/Zurich\)/);
  assert.match(overview, /2026-11-03 · 14:30/);
  assert.match(overview, /Keep my ideas/);
  assert.match(
    f.note("journal/2026/11/03.norg"),
    /Scheduled release · 14:30 \(Europe\/Zurich\)/,
  );
  assert.match(f.note("youtube/guides/schedule.norg"), /14:30 · LuixBits/);
  assert.equal(
    dashboardData(f.options).events.filter((event) => event.kind === "release")
      .length,
    1,
  );
  assert.equal(f.sync().updated, 0);
  const before = read(path.join(f.repoRoot, "config/youtube-plan.json"));
  for (const time of ["24:00", "14:60", "2:30", "14:30:00"])
    assert.throws(
      () => scheduleRelease(f.repoRoot, "sample", "2026-11-03", time),
      /HH:MM/,
    );
  assert.throws(
    () => scheduleRelease(f.repoRoot, "missing", "2026-11-03", "14:30"),
    /existing canonical/,
  );
  assert.equal(read(path.join(f.repoRoot, "config/youtube-plan.json")), before);
  syncNotes({ ...f.options, today: "2026-11-04" });
  assert.doesNotMatch(f.note("youtube/index.norg"), /Scheduled uploads/);
  assert.match(f.note("youtube/released/index.norg"), /\[A useful plan\]/);
  const large = norgTable(
    ["Title"],
    Array.from({ length: 256 }, (_, index) => [`Item ${index}`]),
  );
  assert.equal((large.match(/: A1 : Title/g) || []).length, 2);
  assert.doesNotMatch(large, /: A257/);
});

test("new drafts and proposed calendar topics stay in Ideas until explicitly selected", (t) => {
  const f = fixture(t);
  f.put(
    "docs/video-scripts/next-idea.md",
    "# A possible future video\n\nOnly a draft.\n",
  );
  const plan = JSON.parse(
    read(path.join(f.repoRoot, "config/youtube-plan.json")),
  );
  plan.events.push({
    id: "proposal",
    production: "next-idea",
    title: "A possible future video",
    channel: "LuixBits",
    date: "2026-11-03",
    status: "planned",
  });
  f.put("config/youtube-plan.json", JSON.stringify(plan));
  f.sync();
  let data = dashboardData(f.options);
  assert.equal(data.documents.active, 1);
  assert.equal(
    data.documents.items.find((item) => item.id === "next-idea").status,
    "idea",
  );
  assert.equal(
    data.events.find((event) => event.id === "proposal").proposal,
    true,
  );
  assert.match(f.note("youtube/ideas/index.norg"), /A possible future video/);
  assert.doesNotMatch(
    f.note("youtube/index.norg"),
    /\[A possible future video\]/,
  );
  assert.match(f.note("journal/2026/11/03.norg"), /Proposed topic/);
  updateEvent(f.repoRoot, "sample-release", { status: "done" });
  data = dashboardData(f.options);
  assert.equal(data.priority, null);
  updateDocument(f.repoRoot, "next-idea", "planning", f.options);
  f.sync();
  data = dashboardData(f.options);
  assert.equal(data.documents.active, 2);
  assert.equal(data.priority.id, "next-idea");
  assert.match(f.note("youtube/index.norg"), /\[A possible future video\]/);
  assert.equal(f.sync().updated, 0);
});

test("notes home becomes linked subindexes while the old home and every content note are preserved", (t) => {
  const f = fixture(t);
  f.putNote(
    "work/Space note.norg",
    "@document.meta\ntitle: Space note\n@end\n\n* Work\n\nOriginal work text.\n",
  );
  f.putNote("private/new-flat/tasks.norg", "* Personal tasks\n");
  f.putNote(
    "templates/meeting.norg",
    "@document.meta\ntitle: {TITLE_INPUT}\n@end\n\n* Meeting template\n",
  );
  f.putNote("japanese/flashcards/cards.norg", "* Study cards\n");
  f.putNote(
    "neovim.norg",
    "@document.meta\ntitle: Neovim guide\n@end\n\n* Neovim\n",
  );
  f.putNote(
    "llm-writing-research.norg",
    "@document.meta\ntitle: Writing research\n@end\n\n* Research\n",
  );
  f.sync();
  const original = f.note("index.norg");
  const protectedNotes = [
    "work/Space note.norg",
    "private/new-flat/tasks.norg",
    "templates/meeting.norg",
    "japanese/flashcards/cards.norg",
  ];
  const before = protectedNotes.map((file) => f.note(file));
  const result = organizeNotesHome(f.options);
  assert.equal(f.note(result.archived), original);
  const organizedState = JSON.parse(
    read(path.join(f.repoRoot, "private/work/youtube-notes/state.json")),
  );
  assert.equal(organizedState.files["index.norg"], undefined);
  assert.ok(organizedState.notesIndexHashes["index.norg"]);
  assert.deepEqual(f.sync().conflicts, []);
  assert.match(f.note("index.norg"), /\[YouTube\]/);
  assert.equal(
    (f.note("index.norg").match(/youtube\/index:/g) || []).length,
    1,
  );
  assert.doesNotMatch(
    f.note("index.norg"),
    /My existing home|Video production\n/,
  );
  assert.match(
    f.note("work/index.norg"),
    /work\/Space note:\}\[Space note\]/,
  );
  assert.match(f.note("private/index.norg"), /private\/new-flat\/index/);
  assert.match(
    f.note("computer-science/index.norg"),
    /neovim:\}\[Neovim guide\]/,
  );
  assert.match(
    f.note("research/index.norg"),
    /llm-writing-research:\}\[Writing research\]/,
  );
  assert.match(f.note(".indexes/templates.norg"), /\[Meeting\]/);
  assert.match(f.note(".indexes/journal/2026/10.norg"), /October 2026/);
  assert.equal(
    existsSync(path.join(f.notesRoot, "templates/index.norg")),
    false,
  );
  assert.equal(
    existsSync(path.join(f.notesRoot, "japanese/flashcards/index.norg")),
    false,
  );
  assert.equal(existsSync(path.join(f.notesRoot, "journal/index.norg")), false);
  assert.deepEqual(
    protectedNotes.map((file) => f.note(file)),
    before,
  );
  for (const { body } of workspaceIndexPages({
    ...f.options,
    archivedHome: result.archived,
  }).values())
    for (const [, target] of body.matchAll(/\{:[$]\/([^:}]+):\}/g))
      assert.ok(
        existsSync(path.join(f.notesRoot, target + ".norg")),
        "Missing workspace link: " + target,
      );
  assert.deepEqual(organizeNotesHome(f.options), { alreadyOrganized: true });
  assert.equal(f.sync().updated, 0);
  f.putNote("work/Another note.norg", "* Another note\n");
  f.sync();
  assert.match(f.note("work/index.norg"), /Another note/);
  f.putNote("recipes/tea.norg", "* Tea\n");
  f.sync();
  assert.match(f.note("index.norg"), /\[Recipes\]/);
  rmSync(path.join(f.notesRoot, "recipes/tea.norg"));
  f.sync();
  assert.doesNotMatch(f.note("index.norg"), /\[Recipes\]/);
  assert.doesNotMatch(f.note("recipes/index.norg"), /recipes\/tea/);
  assert.match(
    f.note("recipes/index.norg"),
    /No notes are currently indexed here/,
  );
  const edited = f
    .note("index.norg")
    .replace("\n* Notes\n", "\n* My hand-edited index\n");
  f.putNote("index.norg", edited);
  assert.ok(f.sync().conflicts.includes("index.norg"));
  assert.equal(f.note("index.norg"), edited);
});

test("synced folder overviews lead their subindexes and remain user-owned", (t) => {
  const f = fixture(t);
  const overview = "* Work overview\n\nMy project links and priorities.\n";
  const nested = "* Testing overview\n\nExisting evidence and test links.\n";
  f.putNote("work/index.norg", overview);
  f.putNote("work/testing/index.norg", nested);
  f.putNote("work/testing/first-test.norg", "* First test\n");
  f.sync();
  organizeNotesHome(f.options);
  assert.deepEqual(f.sync().conflicts, []);
  const work = f.note("work/index.norg");
  assert.ok(work.startsWith(overview));
  assert.match(work, /work\/testing\/index/);
  assert.ok(f.note("work/testing/index.norg").startsWith(nested));
  assert.doesNotMatch(work, /work\/index:/);
  const edited = work + "\nA new personal priority.\n";
  f.putNote("work/index.norg", edited);
  assert.deepEqual(f.sync().conflicts, []);
  assert.equal(f.note("work/index.norg"), edited);
  assert.equal(f.sync().updated, 0);
});

test("full-note indexing skips external symlinks and refuses a symlink home", (t) => {
  const f = fixture(t);
  const outside = path.join(f.root, "outside");
  mkdirSync(outside);
  writeFileSync(path.join(outside, "secret.norg"), "* Outside workspace\n");
  symlinkSync(outside, path.join(f.notesRoot, "external"), "dir");
  assert.ok(
    ![...workspaceIndexPages(f.options).values()].some((page) =>
      page.body.includes("secret"),
    ),
  );
  rmSync(path.join(f.notesRoot, "index.norg"));
  symlinkSync(
    path.join(outside, "secret.norg"),
    path.join(f.notesRoot, "index.norg"),
  );
  assert.throws(() => organizeNotesHome(f.options), /symlink notes index/);
  assert.equal(
    read(path.join(outside, "secret.norg")),
    "* Outside workspace\n",
  );
});

test("Neovim opens both indexes, edits task options and preserves back navigation", (t) => {
  const f = fixture(t);
  f.put("scripts/youtube-notes.mjs", read(cli));
  f.put("scripts/youtube-workspace.mjs", read(fileURLToPath(new URL("./youtube-workspace.mjs", import.meta.url))));
  f.put(
    "scripts/norg-table.mjs",
    read(fileURLToPath(new URL("./norg-table.mjs", import.meta.url))),
  );
  f.put(
    "scripts/notes-index.mjs",
    read(fileURLToPath(new URL("./notes-index.mjs", import.meta.url))),
  );
  f.put(
    "scripts/youtube-documents.mjs",
    read(fileURLToPath(new URL("./youtube-documents.mjs", import.meta.url))),
  );
  f.put(
    "scripts/youtube-notes-structure.mjs",
    read(
      fileURLToPath(new URL("./youtube-notes-structure.mjs", import.meta.url)),
    ),
  );
  const script = fileURLToPath(
    new URL("./youtube-dashboard.test.lua", import.meta.url),
  );
  f.putNote(
    "work/Space note.norg",
    "@document.meta\ntitle: Space note\n@end\n\n* Work\n\nOriginal work text.\n",
  );
  f.sync();
  organizeNotesHome(f.options);
  f.sync();
  const result = spawnSync(
    "nvim",
    ["-u", "NONE", "-i", "NONE", "--headless", "-l", script],
    {
      encoding: "utf8",
      timeout: 30000,
      env: {
        ...process.env,
        LUIX_YOUTUBE_NO_WATCH: "1",
        LUIX_YOUTUBE_TEST_REPO: f.repoRoot,
        LUIX_YOUTUBE_TEST_NOTES: f.notesRoot,
        LUIX_YOUTUBE_SOURCE_ROOT: path.resolve(path.dirname(cli), ".."),
        XDG_STATE_HOME: path.join(f.root, "nvim-state"),
        NVIM_LOG_FILE: path.join(f.root, "nvim.log"),
      },
    },
  );
  assert.equal(result.error, undefined, String(result.error));
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout + result.stderr, /YOUTUBE_DASHBOARD_TEST_OK/);
});

test("Norg conversion preserves code and rewrites canonical source links", () => {
  const converted = markdownToNorg(
    "# Demo\n\n```sh\nprintf '# text'\n```\n\n**Result** [manual](https://example.com)\n",
  );
  assert.match(converted, /^\* Demo/);
  assert.match(converted, /@code sh\nprintf '# text'\n@end/);
  assert.match(converted, /\*Result\* \{https:\/\/example.com\}\[manual\]/);
});

test("refuses dangling destination symlinks and keeps their outside target untouched", (t) => {
  const f = fixture(t);
  const target = path.join(
    f.notesRoot,
    "youtube/LuixBits/projects/sample/planning/sample.norg",
  );
  const outside = path.join(f.root, "outside.norg");
  mkdirSync(path.dirname(target), { recursive: true });
  symlinkSync(outside, target);
  assert.throws(f.sync, /symlink note/);
  assert.equal(existsSync(outside), false);
});

test("installer is idempotent and refuses an unrelated plugin", (t) => {
  const f = fixture(t);
  const nvimConfig = path.join(f.root, "nvf");
  f.put("nvim/youtube-notes/plugin/youtube-notes.lua", "-- plugin\n");
  const first = installNeovim({ repoRoot: f.repoRoot, nvimConfig });
  assert.deepEqual(installNeovim({ repoRoot: f.repoRoot, nvimConfig }), first);
  rmSync(first.installed);
  writeFileSync(first.installed, "-- user's plugin\n");
  assert.throws(
    () => installNeovim({ repoRoot: f.repoRoot, nvimConfig }),
    /Refusing to replace/,
  );
  assert.equal(read(first.installed), "-- user's plugin\n");
});

async function waitFor(predicate) {
  const deadline = Date.now() + 7000;
  while (Date.now() < deadline) {
    if (predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw new Error("Timed out waiting for automatic notes sync");
}

test("watcher automatically exports narration and document metadata changes", async (t) => {
  const f = fixture(t);
  f.sync();
  organizeNotesHome(f.options);
  f.sync();
  const child = spawn(
    process.execPath,
    [
      cli,
      "watch",
      "--repo-root",
      f.repoRoot,
      "--notes-root",
      f.notesRoot,
      "--today",
      "2026-10-29",
    ],
    { stdio: ["ignore", "pipe", "pipe"] },
  );
  let output = "";
  let errors = "";
  child.stdout.on("data", (chunk) => {
    output += chunk;
  });
  child.stderr.on("data", (chunk) => {
    errors += chunk;
  });
  try {
    await waitFor(() => output.includes('"updated":'));
    f.put(
      "docs/video-scripts/sample/sample-chapter02.md",
      "<!-- title: Next useful example -->\n\nAutomatically mirrored narration.\n",
    );
    const target = path.join(
      f.notesRoot,
      "youtube/LuixBits/projects/sample/narration/sample-chapter02.norg",
    );
    await waitFor(() => existsSync(target));
    assert.match(read(target), /Automatically mirrored narration/);
    f.put(
      "config/youtube-documents.json",
      JSON.stringify({
        version: 1,
        items: { sample: { status: "done", tags: ["demo"] } },
      }),
    );
    await waitFor(
      () =>
        read(target).includes("Status: Done") &&
        f.note(location("sample").note).includes("Status: Done"),
    );
    assert.match(f.note(location("sample").note), /Status: Done/);
    f.putNote(
      "work/New note.norg",
      "@document.meta\ntitle: A new work note\n@end\n\n* Notes\n",
    );
    await waitFor(
      () =>
        existsSync(path.join(f.notesRoot, "work/index.norg")) &&
        f.note("work/index.norg").includes("A new work note") &&
        f.note("index.norg").includes("[Work]"),
    );
    assert.equal(errors, "");
  } catch (error) {
    throw new Error(
      `${error.message}; watcher stdout: ${output}; watcher stderr: ${errors}`,
    );
  } finally {
    const stopped = new Promise((resolve) => child.once("exit", resolve));
    child.kill("SIGTERM");
    await stopped;
  }
});


test("the packaged publisher watches canonical sources after shared workspace migration", async (t) => {
  const f = fixture(t);
  f.sync();
  exportWorkspace(f.options);
  const child = spawn(process.execPath, [cli, "watch", "--repo-root", f.repoRoot, "--notes-root", f.notesRoot, "--today", "2026-10-29"], {
    stdio: ["ignore", "pipe", "pipe"], env: { ...process.env, YOUTUBE_NOTES_PORTABLE: "1" },
  });
  let output = "", errors = "";
  child.stdout.on("data", chunk => { output += chunk; });
  child.stderr.on("data", chunk => { errors += chunk; });
  try {
    await waitFor(() => output.includes('"updated":'));
    f.put("docs/video-scripts/sample/sample-chapter02.md", "<!-- title: New chapter -->\n\nAutomatically exported through the packaged publisher.\n");
    await waitFor(() => existsSync(path.join(f.notesRoot, "youtube/LuixBits/projects/sample/narration/sample-chapter02.norg")));
    updateDocument(f.notesRoot, "sample", "done", { notesRoot: f.notesRoot });
    await waitFor(() => f.note("youtube/LuixBits/projects/sample/index.norg").includes("Status: Done"));
    assert.match(f.note("youtube/LuixBits/projects/sample/index.norg"), /Automatically exported through the packaged publisher/);
    assert.equal(dashboardData({ repoRoot: f.notesRoot, notesRoot: f.notesRoot }).documents.items.find(item => item.id === "sample").scripts, 2);
    assert.equal(errors, "");
  } finally {
    if (child.exitCode === null) { const stopped = new Promise(resolve => child.once("exit", resolve)); child.kill("SIGTERM"); await stopped; }
  }
});
