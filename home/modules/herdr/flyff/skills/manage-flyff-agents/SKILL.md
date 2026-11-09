---
name: manage-flyff-agents
description: Operate Luix's Flyff Herdr workspaces on the mini PC, assign scoped tasks to installed coding agents, coordinate reviews and integration, and troubleshoot the local Strata connection. Use for this Flyff agent workflow, not ordinary Flyff implementation or unrelated Herdr sessions.
---

# Manage Flyff agents

Use `herdr-flyff` and its native CLI tabs. The owner gives normal prompts directly;
do not reintroduce mandatory task-ID forms or menus. Preserve authorization and
existing work. Keep Greenhouse disconnected unless the owner changes that direction.
This skill assigns no game features itself.

## Locations

| Location | Role |
| --- | --- |
| Main PC `192.168.18.10` | Strata inference; Nix source `/home/luix/luix_nix_config` |
| Mini PC `luix@192.168.18.13` | Herdr, CLIs, development checkouts and live Flyff |
| Mini PC `~/projects/flyff-agents/repo` | Development baseline; no push remote/deployment hook |
| Mini PC `~/projects/flyff-agents/worktrees/AREA-AGENT` | Persistent checkout and branch per agent in each area |
| Mini PC `~/homelab-agents/FlyffServer/flyff-project` | Original/live project; not an agent working directory |

Sources: main PC `home/modules/herdr/flyff/`, mirrored to mini PC
`~/server_configuration/modules/agents/flyff-herdr/`. Read its README for details;
the installed guide is `~/projects/flyff-agents/control/README.md`.
For owner instructions, read [the runbook](references/runbook.md).

## Inspect and assign

On the mini PC inspect `flyff board`, `herdr --session herdr-flyff agent list`,
`opencode-local --status` and, when relevant, `devin auth status`. Installation
does not prove login or successful inference. Never collect login tokens in chat.

Game covers server/client/protocol/content; Web covers frontend/backend/accounts;
Review provides independent review; Control holds the guide, board and shell.
All work areas offer Codex, Kimi, Claude, OpenCode Local, Hermes Local and Devin.
Choose by task and available provider, without an unmeasured quality ranking.

Read AGENTS.md, Agent.md, the complete SESSION-HANDOFF.md and component guidance
before choosing work. Later owner directions supersede older observations. Consult
`.flyff/snapshot.json` for excluded inputs. Missing evidence is not a pass.
Do not implement historical unfinished work just because it appears in the handoff.

Send one bounded normal prompt: objective, component and acceptance checks. The
agent's own checkout is already selected. Only send prompts when the user authorizes
that assignment; setup alone starts no tasks. Give each change one owner. Checkouts
prevent file overwrites, but scope ownership and shared API/protocol/auth/schema/
lockfile/migration/patch numbers require explicit coordination. No automatic
scheduler or scope reservations enforce this. Preserve immutable upstream and
the numbered server-patch workflow.

Start with at most two active implementers plus one reviewer; run heavy single-worker
builds and local-model requests one at a time. Idle CLIs may stay open. Use disposable
test data and distinct ports. Native permissions stay enabled; these boundaries
are instructions, not OS sandboxes. Do not modify live services/databases, another
agent's checkout or the baseline as part of an implementation task.

## Review and integrate

Inspect the diff/tests, then commit intended files in the implementer's checkout
with `[Flyff] Description`. Give a different agent the exact commit hash and review
scope. Shared Git objects make `git show COMMIT` available everywhere. The review
checkout is not automatically at that version: verify it is clean before switching
for tests/source inspection. Never reset unfinished work. Codex/Kimi/Claude/OpenCode
review tabs use native read-only/plan modes; Devin and Hermes retain normal
permissions and rely on review instructions.

Within authorization, integrate accepted commits into the development baseline
one at a time and run combined checks. Preserve conflicts/unfinished work. Update
a clean agent branch before dependent work. Integration does not deploy, restart,
push or refresh the running game/website. Legacy `flyff create/run/audit/release`
tasks may exist; preserve their records without requiring that old workflow.

## Model connection

OpenCode Local uses `opencode-local`. Hermes uses the installed runtime with
`HERMES_HOME=~/projects/flyff-agents/hermes`, Strata and terminal/file tools.
Never substitute `hermes-greenhouse` or copy its profile/credentials. A runtime
path containing that name does not activate its profile. Hermes requires at least
64,000 served context tokens; check live metadata, then verify a real call before
claiming inference works. Restart local sessions after changing normal/abliterated
Qwen. Cloud CLIs retain their own provider settings.

## Herdr maintenance

Read `herdr --skill` before controlling panes and installed `--help` for syntax.
Always target `--session herdr-flyff` on the mini PC. Get pane IDs from live results
or `control/layout.json`. Inspect foreground processes before sending input; never
type shell commands into an agent or provider dialog. `agent get` uses the fields
`agent` and `agent_status`.

`flyff setup` refreshes guides, creates missing tabs and opens native agents only
in idle shells or its own obsolete task menus. It preserves real agents and jobs.
An individual idle tab can run `flyff open AREA AGENT`; no task ID is required.
Detach with Ctrl+B then Q. Stopping terminates agents; do it only when intended.
Do not stop other sessions for a protocol mismatch. The retired `herdr-minipc`
command redirects here; do not recreate its layout. Preserve checkouts on uninstall.

The mini-PC Herdr lacks the desktop's custom `inactive_space_bg` theme key. Do not
copy it into Flyff config. Validate and reload config without restarting agents.

Before host-specific Nix work, use `verify-nixos-host`: live identity, matching
flake, and root/boot preflight for activation handoffs. Do not reuse old checks.
Repository rules prohibit agent-run `nixos-rebuild` and Home Manager activation.
Standalone package installation needs no system activation.
