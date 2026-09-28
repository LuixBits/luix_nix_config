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

## Codex and Claude Code

Both CLIs are pinned in `home/modules/programming/default.nix`, shared by all
machines. Codex uses the official release bundle; Claude Code uses the official
binary with Nixpkgs' runtime dependencies and binary patching. `codex-new` is an
alias for the same pinned Codex package.

To update either CLI, change its version and download hash in that module,
validate the package, then rebuild normally and restart the CLI. Updating
`flake.lock` alone does not change these version pins. Claude's package disables
its self-updater; manage these installations through Nix.

Get each download's hash with the desired release version substituted below:

```sh
nix store prefetch-file --json 'https://releases.openai.com/codex/releases/<version>/codex-package-x86_64-unknown-linux-musl.tar.gz'
nix store prefetch-file --json 'https://downloads.claude.ai/claude-code-releases/<version>/linux-x64/claude'
```

Use the returned `hash` in the corresponding `fetchurl`. Check current versions
against the [Codex changelog](https://learn.chatgpt.com/docs/changelog) and
[Claude Code changelog](https://code.claude.com/docs/en/changelog).

Model choice is separate from the installed CLI version. For example, start
Codex with `codex --model gpt-6-sol`, or Claude with `claude --model opus` or
`claude --model fable`. `/model` opens each CLI's model picker. Availability also
depends on the signed-in account and organization policies.

The Codex activation defaults in the programming module currently set
`gpt-6-astra` with `xhigh` reasoning on every rebuild. Change those defaults in
Nix if you want a different persistent model; a local picker choice can be
overwritten by the next rebuild. Claude's model choice stays in its user
settings.

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
