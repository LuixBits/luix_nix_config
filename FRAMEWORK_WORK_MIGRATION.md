# Temporary Framework work-host migration plan

Status: handoff plan for running Codex on the new Framework laptop after a
normal NixOS installation. Remove this file after the Framework has taken over
`#work` and the legacy Surface configuration has been retired.

## Starting point

The user will do these steps manually before asking Codex to continue:

1. Install NixOS normally on the Framework laptop, including the desired disk
   layout and encryption.
2. Create the user `luiz` with UID 1000 and home directory `/home/luiz`.
3. Boot and confirm that the installer-created NixOS system works.
4. Install Git and Codex.
5. Clone this repository to `/home/luiz/luix_nix_config`.
6. Ask Codex to read `AGENTS.md` and this file, then continue the migration.

This plan does not partition or format disks. Codex must treat the working
installer configuration in `/etc/nixos` as the recovery configuration until
the new flake configuration has booted successfully.

## Required safety rules

- Follow `AGENTS.md`. In particular, Codex must never run `nixos-rebuild`,
  `home-manager switch`, or an activation package.
- Keep `nixosConfigurations.work` pointing at the existing Surface during the
  initial Framework bring-up.
- Bring up the Framework through a temporary `#framework-work` output.
- Do not copy the Surface hardware configuration into the Framework host.
- Do not delete `/etc/nixos`. Move it to a timestamped backup immediately
  before creating the symlink, and verify the backup exists.
- Do not overwrite unrelated or uncommitted repository changes.
- Do not commit hardware inventory, serial numbers, credentials, SSH keys, VPN
  material, or other secrets.
- Do not commit, tag, push, or change remote state unless the user explicitly
  requests it.
- Use `path:/home/luiz/luix_nix_config` while the generated hardware file or
  other required files are untracked.
- Stop and ask the user if the installed username/home, filesystem layout,
  encryption setup, or detected hardware differs materially from this plan.

## Phase 1: inspect the fresh laptop and repository

Before editing anything, Codex should:

1. Read `AGENTS.md` completely.
2. Check `git status --short`, the current branch, remotes, and recent commits.
3. Confirm the account is `luiz`, UID 1000, with `/home/luiz` as its home.
4. Inspect, without saving serial-number-bearing output in the repository:
   - `/sys/class/dmi/id/sys_vendor`
   - `/sys/class/dmi/id/product_name`
   - `/sys/class/dmi/id/product_version`
   - `lscpu`
   - `lspci -nnk`
   - `lsusb`
   - `lsblk -f`
   - `findmnt` for `/` and `/boot`
   - `nixos-version`
   - the existing `/etc/nixos/configuration.nix`
   - the existing `/etc/nixos/hardware-configuration.nix`
5. Confirm that this is the expected Framework model and that the CPU/GPU are
   AMD. Record only the model family needed to select configuration modules.
6. Determine the `system.stateVersion` from the fresh installer configuration.
   Do not inherit the Surface's forced state version blindly.

Codex should summarize the detected model, storage layout, encryption, root and
boot filesystems, GPU, wireless adapter, and installer state version before
making changes.

## Phase 2: preserve the Surface and separate role from machine

The initial migration must support both physical laptops concurrently.

Refactor the flake and modules so these concepts are separate:

- Flake output name, initially `work` or `framework-work`.
- Network hostname.
- Home/profile role, `work`.
- Physical machine identity, `surface` or `framework`.

Use a layout along these lines, adapting it to the repository rather than
forcing needless churn:

```text
hosts/
  roles/work.nix
  work-surface/
    default.nix
    hardware-configuration.nix
  work-framework/
    default.nix
    hardware-configuration.nix
```

During bring-up, the outputs must be:

```text
#work            -> existing Surface configuration
#framework-work  -> new Framework configuration
```

The work role should hold settings shared by both machines, including the
`luiz` user, work networking entries, AppImage support, work development
services, and the shared Work Home Manager profile.

Keep these settings Surface-only:

- Intel CPU/media configuration.
- NVIDIA configuration and forced video drivers.
- The Surface Laptop Studio libinput quirk.
- The Intel `/dev/dri/...00:02.0-render` Niri override.
- Surface panel/display identities.
- Any DisplayLink/`evdi`, reboot, kernel, or power-button workarounds that were
  added specifically for the Surface.
- The Surface disk UUIDs in its generated hardware configuration.

For the Framework:

- Start with its generated hardware configuration.
- Enable AMD microcode and the normal AMD graphics path.
- Do not import the repository's current AMD feature blindly: it includes ROCm
  OpenCL intended for existing AMD machines and may be unnecessary here.
- Identify the exact Framework model before adding a model-specific
  `nixos-hardware` module or other tuning.
- Keep Framework display and power settings machine-specific.

Update Home Manager host checks to use a work-role argument for shared work
behaviour and a machine argument for hardware-specific behaviour. In
particular, the Framework must receive the work applications without receiving
the Surface's Intel render-node override or old internal-panel profile.

Also update the `buildall` and `flakeonly` host handling so the temporary output
can be selected safely. Preserve their root/boot UUID preflight protection.
Check any code that assumes the flake output name always equals
`networking.hostName`.

## Phase 3: capture the Framework hardware configuration

Before changing `/etc/nixos`, Codex should obtain a fresh generated hardware
configuration with:

```bash
sudo nixos-generate-config --show-hardware-config
```

Inspect the output and compare it with the installer-created
`/etc/nixos/hardware-configuration.nix`. Then add the verified generated content
to `hosts/work-framework/hardware-configuration.nix` using the normal repository
editing workflow.

The generated configuration must include the actual Framework root and boot
devices. Preserve installer-generated LUKS, swap, resume, or filesystem details
where applicable. Never reuse UUIDs from `hosts/work` or another machine.

The new Framework host module should import:

- Its own `hardware-configuration.nix`.
- The common NixOS base.
- The shared work role.
- Only the hardware and laptop features justified by the detected Framework
  model.

## Phase 4: validate before replacing `/etc/nixos`

Codex must perform evaluation only, not a build or activation. At minimum:

1. Evaluate the full Framework system derivation through
   `path:/home/luiz/luix_nix_config#framework-work`.
2. Confirm that its configured root and boot devices match `findmnt`/`lsblk`.
3. Confirm that the Framework output contains AMD rather than Intel/NVIDIA
   hardware settings.
4. Confirm that the configured user is `luiz`, UID 1000.
5. Evaluate the existing `#work`, `#pc`, and `#l` outputs to ensure the
   refactor did not break them.
6. Run formatting and `git diff --check` validation.
7. Show the user a concise summary of the changes and any remaining hardware
   uncertainty.

Do not proceed to the symlink if the Framework output fails evaluation or its
filesystem devices do not match the running laptop.

## Phase 5: preserve `/etc/nixos` and create the repository symlink

This changes system state and requires the user's explicit confirmation at the
time Codex reaches this phase.

Resolve the repository to exactly:

```text
/home/luiz/luix_nix_config
```

Then:

1. Inspect `/etc/nixos` and refuse to operate if it is an unexpected symlink or
   special file.
2. Choose a unique timestamped backup path such as
   `/etc/nixos.installer-backup-YYYYMMDD-HHMMSS` and verify it does not exist.
3. Move the installer-created `/etc/nixos` directory to that backup path.
4. Create `/etc/nixos` as an absolute symlink to
   `/home/luiz/luix_nix_config`.
5. Verify both the symlink target and the preserved backup.
6. Re-run the Framework evaluation through the symlink and re-check root/boot
   devices.

Never use recursive deletion here. If symlink creation fails, restore the
installer directory immediately.

## Phase 6: hand activation back to the user

Codex must not run the switch. After all validation succeeds, ask the user to
run this exact first-switch command in their terminal:

```bash
sudo nixos-rebuild switch --flake path:/home/luiz/luix_nix_config#framework-work
```

The `path:` form is intentional for the first switch because the generated
Framework files may not be committed yet.

After the user reports success, ask them to reboot once. If the switch or boot
fails, use the previous boot generation and the preserved installer
configuration for recovery; do not improvise destructive repairs.

## Phase 7: post-reboot hardware verification

On the Framework, verify:

- Boot and encrypted-volume unlock.
- Wi-Fi, Bluetooth, audio, microphone, webcam, and fingerprint reader.
- Internal display, scaling, brightness keys, and keyboard controls.
- AMD graphics acceleration.
- Suspend/resume and battery behaviour.
- USB-C/USB4, the work dock, and each external-monitor arrangement.
- `fwupd` device detection.
- Docker and required work development services.
- Niri, Noctalia, portals, keyring, and the Work Home Manager applications.

Collect the Framework's actual Niri output identities after boot and add a
machine-specific display profile. Do not replace the Surface display profile
until the legacy host is retired.

Configuration migration does not migrate user data. Handle SSH/GPG keys, VPN
enrollment, `/home/luiz/siga`, notes, browser/keyring data, databases, Docker
volumes, and other secrets through a separate secure migration process.

## Phase 8: final `#work` cutover

Only after the Framework has been stable and the user explicitly requests the
cutover:

```text
#work         -> Framework
#work-legacy  -> Surface
```

Update the network hostname, Home Manager role/machine arguments, display
settings, helper-script host selection, and any flake-output/hostname coupling
together. Evaluate both outputs and repeat the filesystem preflight checks.

Codex must again stop and ask the user to run the normal Framework command:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#work
```

Keep `#work-legacy` until the Surface has been wiped or the user confirms it no
longer needs rebuilds. Afterwards, remove the legacy modules and this temporary
plan in a separate reviewed change. A committed, annotated baseline tag should
remain as historical recovery documentation.

## Completion criteria

The migration is complete only when:

- `#work` evaluates for and runs on the Framework.
- Root and boot UUID safeguards match the Framework.
- No Surface-only Intel/NVIDIA/render/display quirks reach the Framework.
- The Work Home Manager profile is active.
- Required laptop and dock hardware passes the post-reboot checks.
- The Surface is either retained under `#work-legacy` or explicitly retired.
- The installer `/etc/nixos` backup is retained until the user approves its
  removal.
- This temporary plan is deleted from the active branch after the migration.
