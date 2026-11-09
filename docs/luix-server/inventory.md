# Luix server disk inventory

Inspected 2026-11-07. HDDs and the existing mirror were read-only; no HDD was formatted, repaired or mounted writable. Inspection mounts are temporary; automatic RAID assembly is disabled.

## Drives

| Drive | Serial | Observed device / state |
| --- | --- | --- |
| Samsung 850 EVO 1 TB | `S21DNSAG224404B` | `/dev/sda`: NixOS root/EFI, unchanged |
| Crucial P2 1 TB | `2107E4F88BFE` | `/dev/nvme0n1`: formatted ext4, `LLM_MODELS`, `/srv/llm` |
| Seagate ST2000DM001 2 TB | `Z8E00JEG` | `/dev/sdb1`: NTFS `Nox`, `/mnt/inspection/nox` |
| WD20EFRX 2 TB | `WD-WCC4M1LFC7C4` | `/dev/sdc2`: old NAS RAID1 member |
| WD20EFRX 2 TB | `WD-WCC4M1LFCYC4` | `/dev/sdd2`: matching RAID1 member |

Recheck serials and mounts before destructive commands; device names can change.

## Data and preservation

WD mirror: `/mnt/inspection/wd-mirror`, **652 GiB used**. Members clean, matching event counters; no resync.

| Directory | Approximate size |
| --- | ---: |
| `LuizBackup/HSLU-LuigiStudium` | **12 GiB study/personal backup; copied** |
| `Public/Shared Series` | 613 GiB |
| `Public/Shared Movies` | 6 GiB |
| `Nas_Prog` | 23 GiB old NAS/Plex configuration |
| `.wdmc` | 203 MiB media metadata |

- Saved: `/home/luix/Mass/backupTemp/HSLU-LuigiStudium-2026-11-07.tar.zst` on the PC, 9.73 GiB; excludes empty `luizperren96`.
- Quick sweep, including hidden folders: no additional personal photos found. `Shared Pictures` is empty; 1,359 study-folder images are already backed up. Other images found were media artwork/screenshots or caches of existing files.
- Remaining NAS partitions/folders hold old settings, databases and Plex/Docker state.
- Nox: 527 KiB visible Steam/Windows remnants; no photos or substantial personal folders found.
- Luix declined movies/series and Steam remnants. HDD erasure and final layout remain pending.

## Health

- All five SMART health checks passed; all three HDD short tests passed. Full surface tests pending.
- HDD reallocated/pending/uncorrectable/CRC counts: zero. ~12,850–12,900 power-on hours; WD pair ~27,000 start/stop cycles.
- NVMe: 5% endurance used, zero media errors; 3,511 historical command-error entries, latest invalid-command-field. Monitor historical temperature warnings.

## Configuration and recovery

- Source: [`hosts/nixos-server`](../../hosts/nixos-server/); deployed at `/etc/nixos`. Filesystem UUIDs: [hardware configuration](../../hosts/nixos-server/hardware-configuration.nix).
- User/home: `luix-server`, `/home/luix-server`; key-only SSH. Change the temporary account/sudo password with `passwd`.
- Original setup backup: `/var/backups/luix-server-2026-11-07/` on the server.
- Local `Server` SSH alias edit awaits local activation; the direct SSH command in the [brief](brief.md) works.
