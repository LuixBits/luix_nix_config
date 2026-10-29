{
  config,
  lib,
  networkHostName ? "pc",
  pkgs,
  ...
}:
let
  defaultFlake = "/etc/nixos";
  defaultHost = networkHostName;
  defaultNixArgs = lib.escapeShellArgs (
    lib.optional config.programs.buildandpush.impure "--impure"
  );
  scriptPath = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.findutils
    pkgs.git
    pkgs.gitleaks
    pkgs.gnugrep
    pkgs.gnused
    pkgs.hostname
    pkgs.jq
    pkgs.nix
    pkgs.nixos-rebuild
    pkgs.util-linux
  ];

  pushConfigs = pkgs.writeShellScriptBin "pushconfigs" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    export PATH=${scriptPath}:$PATH

    COMMIT_MSG="''${1:-[NixOS] Update configuration $(date -Iseconds)}"

    info()  { printf "\033[1;34m[INFO]\033[0m %s\n"  "$*"; }
    warn()  { printf "\033[1;33m[WARN]\033[0m %s\n"  "$*"; }
    error() { printf "\033[1;31m[ERR ]\033[0m %s\n"  "$*" >&2; }

    run_gitleaks() {
      local dir="$1"
      local privilege="$2"
      shift 2

      if [[ "$privilege" == "sudo" ]]; then
        sudo env PATH="${scriptPath}" ${pkgs.gitleaks}/bin/gitleaks "$@" "$dir"
      else
        ${pkgs.gitleaks}/bin/gitleaks "$@" "$dir"
      fi
    }

    scan_staged_secrets() {
      local dir="$1"
      local privilege="$2"

      info "Scanning staged changes in $dir for secrets..."
      if ! run_gitleaks "$dir" "$privilege" git \
        --pre-commit \
        --redact \
        --staged \
        --no-banner; then
        error "Secret scan failed for staged changes in $dir. Nothing was pushed."
        return 1
      fi
    }

    scan_repository_secrets() {
      local dir="$1"
      local privilege="$2"

      info "Scanning committed history in $dir for secrets before push..."
      if ! run_gitleaks "$dir" "$privilege" git \
        --redact \
        --no-banner; then
        error "Secret scan failed for committed history in $dir. Nothing was pushed."
        return 1
      fi
    }

    ensure_repo() {
      local dir="$1"
      if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        return 0
      else
        error "Not a git repo: $dir"
        return 1
      fi
    }

    sudo_git() {
      local dir="$1"
      shift
      if [[ -n "''${SSH_AUTH_SOCK:-}" ]]; then
        sudo env SSH_AUTH_SOCK="''${SSH_AUTH_SOCK}" git -C "$dir" "$@"
      else
        sudo git -C "$dir" "$@"
      fi
    }

    push_normal() {
      local dir="$1"
      info "Committing & pushing $dir (as current user)…"
      git -C "$dir" add -A
      if ! git -C "$dir" diff --cached --quiet; then
        scan_staged_secrets "$dir" normal
        git -C "$dir" commit -m "$COMMIT_MSG"
      else
        info "No staged changes in $dir; skipping commit."
      fi
      local current_branch
      current_branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD)"
      scan_repository_secrets "$dir" normal
      git -C "$dir" push -u origin "$current_branch"
    }

    push_with_sudo() {
      local dir="$1"
      info "Committing & pushing $dir via sudo (preserving SSH agent)…"
      if [[ -z "''${SSH_AUTH_SOCK:-}" ]]; then
        warn "SSH_AUTH_SOCK not set; your SSH key may not be available under sudo."
      fi
      sudo_git "$dir" add -A
      if ! sudo_git "$dir" diff --cached --quiet; then
        scan_staged_secrets "$dir" sudo
        sudo_git "$dir" commit -m "$COMMIT_MSG"
      else
        info "No staged changes in $dir; skipping commit."
      fi
      local current_branch
      current_branch="$(sudo_git "$dir" rev-parse --abbrev-ref HEAD)"
      scan_repository_secrets "$dir" sudo
      sudo_git "$dir" push -u origin "$current_branch"
    }

    push_repo() {
      local dir="$1"
      ensure_repo "$dir" || return 0

      if ! git -C "$dir" remote get-url origin >/dev/null 2>&1; then
        warn "No 'origin' remote in $dir. Skipping."
        return 0
      fi

      if [[ -w "$dir/.git" || -w "$dir/.git/config" ]]; then
        push_normal "$dir"
      else
        push_with_sudo "$dir"
      fi
    }

    main() {
      local -a repos=(
        "$HOME/dotfiles"
        "${defaultFlake}"
        "/etc/nixos"
      )

      declare -A seen=()

      for dir in "''${repos[@]}"; do
        [[ -d "$dir" ]] || continue
        local resolved
        resolved="$(readlink -f "$dir" 2>/dev/null || printf '%s' "$dir")"
        if [[ -n "''${seen[$resolved]:-}" ]]; then
          continue
        fi
        push_repo "$resolved"
        seen["$resolved"]=1
      done

      info "Done."
    }

    main "$@"
  '';

  flakeonly = pkgs.writeShellScriptBin "flakeonly" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    export PATH=${scriptPath}:$PATH
    NIX_ARGS=(${defaultNixArgs})

    info()  { printf "\033[1;34m[INFO]\033[0m %s\n"  "$*"; }
    warn()  { printf "\033[1;33m[WARN]\033[0m %s\n"  "$*"; }
    error() { printf "\033[1;31m[ERR ]\033[0m %s\n"  "$*" >&2; }

    read_live_hostname() {
      local command_name proc_name etc_name
      command_name="$(hostname | tr -d '[:space:]')"
      proc_name="$(tr -d '[:space:]' < /proc/sys/kernel/hostname)"

      if [[ -z "$command_name" || -z "$proc_name" || "$command_name" != "$proc_name" ]]; then
        error "Preflight failed: hostname sources disagree (hostname='$command_name', /proc='$proc_name')."
        return 1
      fi

      if [[ -r /etc/hostname ]]; then
        etc_name="$(tr -d '[:space:]' < /etc/hostname)"
        if [[ -z "$etc_name" || "$command_name" != "$etc_name" ]]; then
          error "Preflight failed: /etc/hostname disagrees (live='$command_name', /etc='$etc_name')."
          return 1
        fi
      fi

      printf '%s' "$command_name"
    }

    preflight_host_identity() {
      local target="$1"
      local live_host configured_host host_attr

      live_host="$(read_live_hostname)" || return 1
      if [[ "$target" != "$live_host" ]]; then
        error "Preflight failed: target '$target' is not this machine's live hostname '$live_host'."
        return 1
      fi

      host_attr="''${FLAKE_REF}#nixosConfigurations.''${target}.config.networking.hostName"
      if ! configured_host="$(nix eval "''${NIX_ARGS[@]}" --raw "$host_attr" 2>/dev/null)"; then
        error "Preflight failed: nixosConfigurations.$target is not defined."
        return 1
      fi
      if [[ "$configured_host" != "$live_host" ]]; then
        error "Preflight failed: target '$target' configures hostname '$configured_host', not '$live_host'."
        return 1
      fi

      info "Preflight OK: live and configured hostname both match ($live_host)."
    }

    check_fs_match() {
      local mountpoint="$1"
      local expected_dev="$2"
      local label="$3"

      if ! findmnt -n "$mountpoint" >/dev/null 2>&1; then
        error "Preflight failed: $mountpoint is not mounted."
        return 1
      fi

      local actual_src actual_uuid expected_uuid expected_real actual_real
      actual_src="$(findmnt -n -o SOURCE "$mountpoint")"
      actual_uuid="$(findmnt -n -o UUID "$mountpoint" 2>/dev/null || true)"

      expected_uuid=""
      if [[ "$expected_dev" == /dev/disk/by-uuid/* ]]; then
        expected_uuid="''${expected_dev##*/}"
      fi

      if [[ -n "$expected_uuid" && -n "$actual_uuid" ]]; then
        if [[ "$expected_uuid" != "$actual_uuid" ]]; then
          error "Preflight failed: $label UUID mismatch for $mountpoint (expected $expected_uuid, got $actual_uuid)."
          return 1
        fi
        info "Preflight OK: $label UUID for $mountpoint matches ($actual_uuid)."
        return 0
      fi

      expected_real="$(readlink -f "$expected_dev" 2>/dev/null || true)"
      actual_real="$(readlink -f "$actual_src" 2>/dev/null || true)"
      if [[ "$expected_dev" == "$actual_src" ]] || [[ -n "$expected_real" && -n "$actual_real" && "$expected_real" == "$actual_real" ]]; then
        info "Preflight OK: $label device for $mountpoint matches ($actual_src)."
        return 0
      fi

      error "Preflight failed: $label device mismatch for $mountpoint (expected $expected_dev, got $actual_src)."
      return 1
    }

    preflight_fs_guard() {
      local host="$1"
      info "Preflight: validating / and /boot for host '$host'..."

      local root_attr boot_attr root_dev boot_dev
      root_attr="''${FLAKE_REF}#nixosConfigurations.''${host}.config.fileSystems.\"/\".device"
      boot_attr="''${FLAKE_REF}#nixosConfigurations.''${host}.config.fileSystems.\"/boot\".device"

      if ! root_dev="$(nix eval "''${NIX_ARGS[@]}" --raw "$root_attr" 2>/dev/null)"; then
        error "Preflight failed: missing fileSystems.\"/\".device for host '$host'."
        return 1
      fi

      if ! boot_dev="$(nix eval "''${NIX_ARGS[@]}" --raw "$boot_attr" 2>/dev/null)"; then
        error "Preflight failed: missing fileSystems.\"/boot\".device for host '$host'."
        return 1
      fi

      check_fs_match "/" "$root_dev" "root"
      check_fs_match "/boot" "$boot_dev" "boot"
    }

    FLAKE_RAW="''${CONFIG_FLAKE:-${defaultFlake}}"
    if [[ -d "$FLAKE_RAW" ]]; then
      # Always resolve local directories through path:. Git-style local flake
      # refs omit untracked files, including generated hardware configuration
      # during the first Framework switch.
      FLAKE_REF="path:$(readlink -f "$FLAKE_RAW")"
    else
      FLAKE_REF="$FLAKE_RAW"
    fi
    HOST="''${CONFIG_HOST:-${defaultHost}}"

    if [[ $# -gt 0 ]]; then
      case "$1" in
        framework|l|pc)
          HOST="$1"
          shift
          ;;
        *)
          error "Usage: flakeonly [framework|l|pc]"
          exit 2
          ;;
      esac
    fi

    nix flake update --flake "$FLAKE_REF"
    preflight_host_identity "$HOST"
    preflight_fs_guard "$HOST"
    sudo nixos-rebuild switch "''${NIX_ARGS[@]}" --flake "''${FLAKE_REF}#''${HOST}"
  '';

  syncNoctalia = pkgs.writeShellScriptBin "syncnoctalia" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    export PATH=${scriptPath}:$PATH

    info()  { printf "\033[1;34m[INFO]\033[0m %s\n"  "$*"; }
    info "Noctalia v5 no longer uses the old JSON sync workflow."
    info "Declarative Noctalia settings live in home/modules/niri/noctalia/default.nix."
  '';

  buildall = pkgs.writeShellScriptBin "buildall" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    export PATH=${scriptPath}:$PATH
    NIX_ARGS=(${defaultNixArgs})

    info()  { printf "\033[1;34m[INFO]\033[0m %s\n"  "$*"; }
    warn()  { printf "\033[1;33m[WARN]\033[0m %s\n"  "$*"; }
    error() { printf "\033[1;31m[ERR ]\033[0m %s\n"  "$*" >&2; }

    read_live_hostname() {
      local command_name proc_name etc_name
      command_name="$(hostname | tr -d '[:space:]')"
      proc_name="$(tr -d '[:space:]' < /proc/sys/kernel/hostname)"

      if [[ -z "$command_name" || -z "$proc_name" || "$command_name" != "$proc_name" ]]; then
        error "Preflight failed: hostname sources disagree (hostname='$command_name', /proc='$proc_name')."
        return 1
      fi

      if [[ -r /etc/hostname ]]; then
        etc_name="$(tr -d '[:space:]' < /etc/hostname)"
        if [[ -z "$etc_name" || "$command_name" != "$etc_name" ]]; then
          error "Preflight failed: /etc/hostname disagrees (live='$command_name', /etc='$etc_name')."
          return 1
        fi
      fi

      printf '%s' "$command_name"
    }

    preflight_host_identity() {
      local target="$1"
      local live_host configured_host host_attr

      live_host="$(read_live_hostname)" || return 1
      if [[ "$target" != "$live_host" ]]; then
        error "Preflight failed: target '$target' is not this machine's live hostname '$live_host'."
        return 1
      fi

      host_attr="''${FLAKE_REF}#nixosConfigurations.''${target}.config.networking.hostName"
      if ! configured_host="$(nix eval "''${NIX_ARGS[@]}" --raw "$host_attr")"; then
        error "Preflight failed: could not evaluate nixosConfigurations.$target (see Nix error above)."
        return 1
      fi
      if [[ "$configured_host" != "$live_host" ]]; then
        error "Preflight failed: target '$target' configures hostname '$configured_host', not '$live_host'."
        return 1
      fi

      info "Preflight OK: live and configured hostname both match ($live_host)."
    }

    ${builtins.readFile ./sync-repo.sh}

    check_fs_match() {
      local mountpoint="$1"
      local expected_dev="$2"
      local label="$3"

      if ! findmnt -n "$mountpoint" >/dev/null 2>&1; then
        error "Preflight failed: $mountpoint is not mounted."
        return 1
      fi

      local actual_src actual_uuid expected_uuid expected_real actual_real
      actual_src="$(findmnt -n -o SOURCE "$mountpoint")"
      actual_uuid="$(findmnt -n -o UUID "$mountpoint" 2>/dev/null || true)"

      expected_uuid=""
      if [[ "$expected_dev" == /dev/disk/by-uuid/* ]]; then
        expected_uuid="''${expected_dev##*/}"
      fi

      if [[ -n "$expected_uuid" && -n "$actual_uuid" ]]; then
        if [[ "$expected_uuid" != "$actual_uuid" ]]; then
          error "Preflight failed: $label UUID mismatch for $mountpoint (expected $expected_uuid, got $actual_uuid)."
          return 1
        fi
        info "Preflight OK: $label UUID for $mountpoint matches ($actual_uuid)."
        return 0
      fi

      expected_real="$(readlink -f "$expected_dev" 2>/dev/null || true)"
      actual_real="$(readlink -f "$actual_src" 2>/dev/null || true)"
      if [[ "$expected_dev" == "$actual_src" ]] || [[ -n "$expected_real" && -n "$actual_real" && "$expected_real" == "$actual_real" ]]; then
        info "Preflight OK: $label device for $mountpoint matches ($actual_src)."
        return 0
      fi

      error "Preflight failed: $label device mismatch for $mountpoint (expected $expected_dev, got $actual_src)."
      return 1
    }

    preflight_fs_guard() {
      local host="$1"
      info "Preflight: validating / and /boot for host '$host'..."

      local root_attr boot_attr root_dev boot_dev
      root_attr="''${FLAKE_REF}#nixosConfigurations.''${host}.config.fileSystems.\"/\".device"
      boot_attr="''${FLAKE_REF}#nixosConfigurations.''${host}.config.fileSystems.\"/boot\".device"

      if ! root_dev="$(nix eval "''${NIX_ARGS[@]}" --raw "$root_attr" 2>/dev/null)"; then
        error "Preflight failed: missing fileSystems.\"/\".device for host '$host'."
        return 1
      fi

      if ! boot_dev="$(nix eval "''${NIX_ARGS[@]}" --raw "$boot_attr" 2>/dev/null)"; then
        error "Preflight failed: missing fileSystems.\"/boot\".device for host '$host'."
        return 1
      fi

      check_fs_match "/" "$root_dev" "root"
      check_fs_match "/boot" "$boot_dev" "boot"
    }

    FLAKE_RAW="''${CONFIG_FLAKE:-${defaultFlake}}"
    if [[ -d "$FLAKE_RAW" ]]; then
      # Always resolve local directories through path:. Git-style local flake
      # refs omit untracked files, including generated hardware configuration
      # during the first Framework switch.
      FLAKE_REF="path:$(readlink -f "$FLAKE_RAW")"
    else
      FLAKE_REF="$FLAKE_RAW"
    fi
    usage() {
      echo "Usage: buildall [--no-pull] [--no-update] [--no-push] [--impure] [--sync-noctalia] <framework|l|pc> [commit-message...]" >&2
      exit "''${1:-2}"
    }

    SYNC_NOCTALIA=0
    PULL=1
    UPDATE=1
    PUSH=1
    HOST=""

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --help|-h)
          usage 0
          ;;
        --no-pull)
          PULL=0
          shift
          ;;
        --no-update)
          UPDATE=0
          shift
          ;;
        --no-push)
          PUSH=0
          shift
          ;;
        --impure)
          NIX_ARGS=(--impure)
          shift
          ;;
        --sync-noctalia)
          SYNC_NOCTALIA=1
          shift
          ;;
        framework|l|pc)
          HOST="$1"
          shift
          break
          ;;
        *)
          usage
          ;;
      esac
    done

    if [[ -z "$HOST" ]]; then
      usage
    fi

    LIVE_HOST="$(read_live_hostname)"
    if [[ "$HOST" != "$LIVE_HOST" ]]; then
      error "Target '$HOST' is not this machine's live hostname '$LIVE_HOST'."
      exit 1
    fi

    if [[ "$PULL" -eq 1 ]]; then
      sync_flake_repo "$FLAKE_RAW"
    else
      check_repo_ready "$FLAKE_RAW"
      info "Using local configuration without Git sync."
    fi

    MSG="''${*:-[NixOS] Update configuration $(date -Iseconds)}"

    if [[ "$SYNC_NOCTALIA" -eq 1 ]]; then
      syncnoctalia "$HOST"
    fi

    if [[ "$UPDATE" -eq 1 ]]; then
      nix flake update --flake "$FLAKE_REF"
    fi
    preflight_host_identity "$HOST"
    preflight_fs_guard "$HOST"
    sudo nixos-rebuild switch "''${NIX_ARGS[@]}" --flake "''${FLAKE_REF}#''${HOST}"
    if [[ "$PUSH" -eq 1 ]]; then
      pushconfigs "$MSG"
    fi
  '';

  pushonly = pkgs.writeShellScriptBin "pushonly" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    export PATH=${scriptPath}:$PATH
    exec pushconfigs "''${1:-}"
  '';
in
{
  options.programs.buildandpush.impure = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Enable impure evaluation in buildall and flakeonly when this user's
      system configuration imports local files outside the flake, such as a
      company CA certificate. Applies to preflight checks and rebuilding.
    '';
  };

  config = {
    home.file.".agents/skills/verify-nixos-host" = {
      source = ./skill;
      force = true;
    };

    home.file.".codex/skills/verify-nixos-host" = {
      source = ./skill;
      force = true;
    };

    home.packages = [
      buildall
      flakeonly
      pushonly
      pushConfigs
      syncNoctalia
    ];
  };
}
