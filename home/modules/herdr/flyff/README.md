# Flyff in Herdr

From the **main PC**, open the mini PC's session:

```sh
herdr --remote luix@192.168.18.13 --session herdr-flyff
```

Commands inside these tabs run on the **mini PC**. On the mini PC itself,
`herdr-flyff` opens the same session. Open an agent tab and type your request
into its normal CLI. There is no task-ID form.

| Space | Purpose |
| --- | --- |
| Flyff Control | Instructions, status board and coordination shell |
| Game - Server and Client | Server, client, protocol, gameplay and content |
| Web - Frontend and Backend | Website, accounts, backend, administration and commerce |
| Review and Integration | A second agent checks changes before they are merged |

Each work area has Nvim, Codex, Kimi, Claude, OpenCode Local, Hermes Local,
Devin and CLI tabs. Native provider login/trust prompts still apply. Nvim opens
this guide; the CLI tab is an ordinary shell. Launching submits no model task.

## Give an agent work

Each area/agent pair has its own branch and persistent checkout, for example
`~/projects/flyff-agents/worktrees/game-opencode` or `worktrees/web-kimi`.
The launcher opens the real CLI there. AGENTS.md and FLYFF-TASK.md describe
its boundaries. Example normal prompt:

> Read the full SESSION-HANDOFF.md and PROJECT-STATUS.md. Summarize the current
> state and suggest three small next tasks. Do not edit anything yet.

For implementation, name one objective, allowed component and expected result.
Give each change one owner. Separate checkouts prevent agents overwriting each
other's working files; they do not prevent conflicting designs or commits.
Coordinate shared API/protocol/auth/schema changes, lockfiles, migrations and
server patch numbers. Preserve immutable upstream and the server patch workflow.
Do not use the live project or databases as a working directory/test fixture.

Start with at most two active implementers and one reviewer. Run heavy builds
one at a time with a single worker, disposable databases and distinct ports.
Run one local-model request at a time; idle CLI tabs can stay open. These limits
are cooperative. Native tool permissions remain enabled; checkout guidance is
not an OS sandbox.

## Review and integration

**Review:** another agent checks a finished diff, tests and possible bugs. Commit
intended source changes in the implementing checkout using `[Flyff] ...`, then
give the reviewer the exact commit hash and review scope. All worktrees share
Git history, so `git show COMMIT` works in the review checkout. Its files are not
automatically switched to that commit. For code/tests at that version, verify
the checkout is clean before switching. Never reset unfinished work.

Codex, Kimi, Claude and OpenCode review tabs start in native read-only/plan mode.
Hermes and Devin retain normal permissions and receive review instructions;
their label is not an enforced filesystem restriction.

**Integration:** combine accepted commits into `~/projects/flyff-agents/repo`
one at a time and run the relevant checks together. This development baseline
has no push remote or deployment hook. Integration does not update the running
Flyff server. Update another agent's clean branch from the baseline before
assigning dependent work; never discard uncommitted changes.

## Models and login

The main PC serves Strata at `http://192.168.18.10:8080/v1`; keep it awake for
OpenCode Local and Hermes Local. Cloud CLIs use their own provider accounts.
Check the connection on the mini PC with `opencode-local --status`.
Hermes requires at least 64,000 context tokens. Its separate profile lives at
`~/projects/flyff-agents/hermes`; it uses the installed runtime without the
Greenhouse profile, credentials or MCP configuration. Greenhouse is disconnected.
After changing the served Qwen model, restart local CLI sessions.

Devin is installed separately through `devin.nix` (official pinned 3000.11.234
Linux bundle). Check `devin auth status` on the mini PC. Only if needed, use
`devin auth login --force-manual-token-flow` there. Enter tokens only into the
native login flow. Installed executables do not imply provider authentication.

## Reconnect and maintain

Detach with **Ctrl+B**, then **Q**; agents continue. After a mini-PC reboot or
full Herdr-server restart, run `flyff setup` on the mini PC to reopen idle agent
tabs. It preserves active agents and other foreground jobs. To reopen just one
agent from its idle shell: `flyff open game opencode`. This opens a new native
conversation in the retained checkout; use the CLI's own session history to
resume a conversation. `flyff menu` is obsolete for normal use; older explicit
task commands remain available for compatibility.

The source baseline preserves the original handoff and records excluded private,
runtime, generated, evidence and binary inputs in `.flyff/snapshot.json`. Missing
inputs do not establish passing tests. The live project remains at
`~/homelab-agents/FlyffServer/flyff-project`.

Package sources: main PC `home/modules/herdr/flyff/`; mini PC
`~/server_configuration/modules/agents/flyff-herdr/`. The standalone Nix profile
package needs no NixOS/Home Manager activation. The mini-PC config excludes
desktop-only Herdr theme keys. The retired `herdr-minipc` command redirects here.

To stop: `herdr session stop herdr-flyff` (terminates its agents). To remove the
stopped layout: `herdr session delete herdr-flyff`. To uninstall launchers:
`nix-env -e flyff-herdr`. Worktrees, branches and history remain intact.
