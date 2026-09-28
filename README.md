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

## Codex, Claude Code, and Herdr updates

All three applications come from the shared `llm-agents` flake input:
[numtide/llm-agents.nix](https://github.com/numtide/llm-agents.nix). It checks for
updates daily and provides a signed binary cache. We keep its own tested
`nixpkgs` revision so its cached packages can be reused. The cache is configured
both for the flake's first rebuild and in the system Nix settings.

Use the standard `codex` and `claude` commands. Herdr's separately packaged
plugins retain their own versions in `home/modules/herdr/default.nix`.

The package maintainers update CLI versions and download hashes. There are no
manual version pins for these three applications in this repository. The
existing `flakeonly` and `buildall` helpers already run `nix flake update`, so
they refresh this input along with the rest of the configuration.

To refresh just these three applications, run this from the repository:

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
