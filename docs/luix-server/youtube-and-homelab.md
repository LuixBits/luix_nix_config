# YouTube and homelab additions

Researched 2026-11-08. No new apps installed. All new services belong on the large server, kept awake with idle power optimized. [Service decisions](services.md) tracks selections.

## Existing workflow and limits

- Keep the current Neorg production dashboard, canonical scripts and `Youtube/<channel>/<production>` layout. Sources: Remotion `docs/output-organization.md` and `docs/production-workflow-review.md`.
- Measured 2026-11-08 locally: `Mass/Youtube` occupies ~783 GiB. The whole Mass NVMe uses ~1.40 TiB; these are different scopes.
- Two 2 TB HDDs mirrored provide ~2 TB nominal capacity, not 4 TB. The separate 2 TB backup disk needs room for history and other hosts.
- Keep active editing on the PC's NVMe. Use the server for protected copies, shared libraries and queued work. Gigabit Ethernet has a theoretical ceiling of 125 MB/s before overhead.

## Priority additions

| Priority | Tool | Practical use / location |
| --- | --- | --- |
| Foundation | Backrest + [restic/rest-server](https://github.com/restic/rest-server) | Large server; backup UI and versioned copies; append-only client access, separate pruning credentials, offline/offsite copy |
| Foundation | [Uptime Kuma](https://github.com/louislam/uptime-kuma) + ntfy | Large server; service checks, backup-success monitors and disk-space alerts; whole-host outage detection needs an independent observer |
| Foundation | [sops-nix](https://github.com/Mic92/sops-nix) | Encrypted service secrets in Git; private decryption keys backed up separately |
| Selected | [Miniflux](https://miniflux.app/features.html) | Large server; release notes, project blogs and channel feeds for video research; PostgreSQL on local SSD |
| Optional | [linkding](https://linkding.link/) | Tag sources by production and retain page snapshots; start with Miniflux's saved articles |
| After backups | Media worker | Large server; reuse existing intake/transcription, generate proxies/contact sheets with [FFmpeg](https://ffmpeg.org/ffmpeg-filters.html), benchmark [whisper.cpp](https://github.com/ggml-org/whisper.cpp) if a server transcription backend is needed |

Miniflux integrates with linkding. Use [SingleFile browser capture](https://linkding.link/archiving/) for selected source snapshots initially. Record publication/retrieval dates and asset licences beside each production. Saving a source does not grant reuse rights.

## Useful later

- Paperless-ngx and AdGuard Home are preferred additions; Forgejo is selected. See [service decisions](services.md) and [migration notes](forgejo-migration.md).
- BentoPDF and IT-Tools selected; changedetection.io declined. [Release/security monitoring](release-security.md) follows the repositories and images actually used.
- [NUT](https://networkupstools.org/features.html): UPS monitoring and graceful shutdown if a supported UPS is available.

Start automation with systemd services/timers. [Node-RED](https://nodered.org/about/) becomes useful if visual, event-driven flows are needed. Defer Kubernetes, another production planner and a full metrics stack until a concrete need appears.

## Operating rules

1. Preserve original recordings, final packages, scripts, project state, voice collections and reusable assets. Classify caches/proxies separately; retain the existing reviewed cleanup process.
2. Pick one authoritative copy per project. Transfer completed recordings through staging, then process them; avoid synchronizing files still being written. [Syncthing propagates deletions](https://docs.syncthing.net/users/faq.html#is-syncthing-my-ideal-backup-application), so use it only where multi-device sync is useful, alongside independent backups.
3. Restore-test a project and an app database monthly. Alert on missing/late backups as well as failed jobs. Append-only access does not protect against the backup host's administrator.
4. Queue heavy jobs, start with one GPU task, and retain source/model/version receipts. Keep the server awake, batch disk activity, and keep monitoring/logs on SSD. Measure idle power before tuning.
5. Give each service only its required folders. Keep live databases on local SSD and take consistent backups before upgrades. A NixOS configuration rollback does not restore changed application data.
6. For each service, record host, URL, state directory, backup/restore method, dependencies and update procedure. Pin releases, review updates regularly, replace setup passwords and retain recovery keys outside the vault/server.

## Order

Large-server storage/restore work → access, secrets and alerts → selected services and project migration → one media-worker pilot. Preserve small-PC capacity for Flyff. No media migration until capacity and existing project references are checked.
