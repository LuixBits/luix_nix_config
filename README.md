# luix_nix_config

NixOS + Home Manager flake for all my machines. One rule keeps it tidy:
**machine stuff lives in `hosts/`, user stuff lives in `home/`.**

## Layout

| Path | What goes here |
| --- | --- |
| `flake.nix` | Inputs, the three hosts, and a couple of runnable packages |
| `hosts/<name>/` | One folder per machine: hardware config + what only it needs |
| `hosts/common/` | Applied to **every** machine (base system, optimisations) |
| `hosts/features/` | Opt-in machine features a host can import (gaming, pia, simracing, work, …) |
| `home/common.nix` | Home Manager config shared by every machine |
| `home/hosts/<name>.nix` | Per-machine Home Manager entry: username + extra modules |
| `home/modules/` | User-level modules (apps, shell, editor, desktop, …) |

## Machines

| Host | What it is | User |
| --- | --- | --- |
| `pc` | AMD desktop — gaming, simracing/VR, Corsair cooling, Ollama | `luix` |
| `l` | Personal laptop | `luix` |
| `framework` | Framework laptop — work machine (work feature + work home module) | `luiz` |

## Rebuild

```sh
sudo nixos-rebuild switch --flake .#<host>
```

Home Manager runs as a NixOS module, so this is the only command — no separate
`home-manager switch`.

The installed `buildall [options] <host> [commit-message...]` helper fetches and
integrates the current branch's upstream, updates flake inputs, verifies the
local hostname and disks, rebuilds, then commits and pushes. Options go before
the host:

| Option | Effect |
| --- | --- |
| `--no-update` | Keep the versions already recorded in `flake.lock` |
| `--no-pull` | Use the current checkout without fetching or integrating Git changes |
| `--no-push` | Leave changes local after rebuilding, without committing or pushing |
| `--impure` | Explicitly allow configuration to read local files outside the flake |

The work module enables `programs.buildandpush.impure`, so `buildall` and
`flakeonly` automatically pass `--impure` for the work configuration, including
their preflight checks. This is needed because the system work module imports
the company CA from `~/.local/share/cloudflare-warp/siga-cloudflare-root.pem`,
which is deliberately kept outside this public repository. Other configurations
use pure evaluation by default. Direct `nixos-rebuild` invocations still need
`--impure` when the configuration reads that local certificate.

Combine the three `--no-*` options to rebuild the current checkout and locked
versions without Git sync, dependency updates, or publishing.

Before integrating remote changes, `buildall` saves the original commit under
`refs/buildall-backups/<timestamp-id>/head`. Staged, unstaged, and non-ignored
untracked files are saved in `/worktree` under the same prefix and in
`git stash list`. These local backups are retained after success and are not
pushed by the helper. On a changed upstream, edits are restored with Git's
three-way content merge; the exact original staging state stays in the backup.

If edits conflict, the helper stops before rebuilding or pushing and keeps the
remote commits and conflict markers. Resolve the files, `git add` them, and
retry. If a new upstream path would overwrite an untracked or ignored local
file, the helper stops before stashing or changing the checkout. Reconcile or
move that local path before retrying; ignored files are never added to backups.
For conflicts between committed changes, the rebase is aborted and the original
checkout is restored.

To inspect or recover the original files without disturbing the working checkout:

```sh
git for-each-ref --format='%(refname)' refs/buildall-backups/
# Use the exact prefix printed by the failed run (without /head or /worktree).
backup='refs/buildall-backups/<timestamp-id>'
recovery_dir="$(mktemp -d)"
git worktree add --detach "$recovery_dir" "$backup/head"
# Only needed when the snapshot includes local edits:
git -C "$recovery_dir" stash apply --index "$backup/worktree"
```

## Codex, Claude Code, Kimi Code, and Herdr updates

All four applications come from the shared `llm-agents` flake input:
[numtide/llm-agents.nix](https://github.com/numtide/llm-agents.nix). It checks for
updates daily and provides a signed binary cache. We keep its own tested
`nixpkgs` revision so its cached packages can be reused. The cache is configured
both for the flake's first rebuild and in the system Nix settings.

Use the standard `codex`, `claude`, and `kimi` commands. Herdr's separately
packaged plugins retain their own versions in `home/modules/herdr/default.nix`.

The package maintainers update CLI versions and download hashes. There are no
manual version pins for these four applications in this repository. The
existing `flakeonly` and `buildall` helpers already run `nix flake update`, so
they refresh this input along with the rest of the configuration.

To refresh just these four applications, run this from the repository:

```sh
nix flake update llm-agents
```

Then rebuild normally and restart the applications. Nix still records the
resolved revisions in `flake.lock`; updating that file is what advances the
versions. Applications do not update themselves between rebuilds, and a new
CLI release can take time to reach `llm-agents`; daily updates do not guarantee
that it always has the newest upstream release immediately.

Model choice is separate from the installed CLI version. For example, start
Codex with `codex --model gpt-6-sol`, or Claude with `claude --model opus` or
`claude --model fable`. `/model` opens each CLI's model picker. Availability also
depends on the signed-in account and organization policies.

The Codex activation defaults in the programming module currently set
`gpt-6-astra` with `xhigh` reasoning on every rebuild. Change those defaults in
Nix if you want a different persistent model; a local picker choice can be
overwritten by the next rebuild. Claude's model choice stays in its user
settings.

## Graphify code indexes

The programming module installs Graphify 0.9.48, `graphify-project` and
`graphify-all`, plus the Graphify skill and MCP connections for Codex and Kimi.
Set `programs.graphify.projectRoots` in `home/hosts/<host>.nix` to select the
repositories refreshed by `graphify-all`; missing directories are skipped.

The module also adds mandatory Graphify guidance to Codex's global `AGENTS.md`
and installs the skill through `programs.codex.skills`. The programming module
owns the base global instructions, including commit-message conventions.
For indexed code tasks, Codex must make a relevant query before broad source
exploration or edits and report a useful finding or a concrete reason for
skipping Graphify. This is an instruction, not a runtime enforcement hook.
After activating configuration changes, start a new Codex session so the updated
global instructions load. Repository `AGENTS.md` files can add local requirements.

```sh
graphify-project build /path/to/project   # First code-only build and registration
graphify-project update /path/to/project  # Refresh code and global graph
graphify-project status /path/to/project
graphify-project global                   # List registered projects
graphify-all                              # Refresh this host's configured roots
```

Extraction is local and code-only. Each repository keeps its generated index
in the ignored `graphify-out/` directory; use `.graphifyignore` to exclude
runtime data and generated or vendored code. MCP queries should pass the
absolute repository root as `project_path`; the default graph merges registered
projects. Graphify 0.9.48 does not parse Nix, so this repository's graph covers
supported scripts and configuration formats only. Always verify results in source.

## Adding something new

- Needs root, a service, udev, kernel, firewall? → `hosts/features/`, import it from the host.
- A user program or dotfile? → `home/modules/`, import it from `home/common.nix`
  (all machines) or `home/hosts/<name>.nix` (one machine).
- Never point from `hosts/` into `home/` or the other way around — if both sides
  are needed (like simracing), split it into a feature and a home module.

<details>
<summary>Runnable packages</summary>

| Command | Purpose |
| --- | --- |
| `nix run .#pia-setup` | PIA VPN dedicated-IP setup/connect (source: `hosts/features/pia/`) |
| `nix run .#openlinkhub-emergency` | Temporary cooling service on the pc without rebuilding (source: `hosts/features/corsair-cooling/`) |

</details>
