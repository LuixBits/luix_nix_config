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
