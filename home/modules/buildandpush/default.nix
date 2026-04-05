{ pkgs, lib, ... }:
let
  defaultFlake = "/etc/nixos";
  defaultHost = "pc";
  scriptPath = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.findutils
    pkgs.git
    pkgs.gnugrep
    pkgs.gnused
    pkgs.nix
    pkgs.nixos-rebuild
    pkgs.util-linux
  ];

  pushConfigs = pkgs.writeShellScriptBin "pushconfigs" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    export PATH=${scriptPath}:$PATH

    COMMIT_MSG="''${1:-update: $(date -Iseconds)}"

    info()  { printf "\033[1;34m[INFO]\033[0m %s\n"  "$*"; }
    warn()  { printf "\033[1;33m[WARN]\033[0m %s\n"  "$*"; }
    error() { printf "\033[1;31m[ERR ]\033[0m %s\n"  "$*" >&2; }

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
        git -C "$dir" commit -m "$COMMIT_MSG"
      else
        info "No staged changes in $dir; skipping commit."
      fi
      local current_branch
      current_branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD)"
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
        sudo_git "$dir" commit -m "$COMMIT_MSG"
      else
        info "No staged changes in $dir; skipping commit."
      fi
      local current_branch
      current_branch="$(sudo_git "$dir" rev-parse --abbrev-ref HEAD)"
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

    info()  { printf "\033[1;34m[INFO]\033[0m %s\n"  "$*"; }
    warn()  { printf "\033[1;33m[WARN]\033[0m %s\n"  "$*"; }
    error() { printf "\033[1;31m[ERR ]\033[0m %s\n"  "$*" >&2; }

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

      if ! root_dev="$(nix eval --raw "$root_attr" 2>/dev/null)"; then
        error "Preflight failed: missing fileSystems.\"/\".device for host '$host'."
        return 1
      fi

      if ! boot_dev="$(nix eval --raw "$boot_attr" 2>/dev/null)"; then
        error "Preflight failed: missing fileSystems.\"/boot\".device for host '$host'."
        return 1
      fi

      check_fs_match "/" "$root_dev" "root"
      check_fs_match "/boot" "$boot_dev" "boot"
    }

    FLAKE_RAW="''${CONFIG_FLAKE:-${defaultFlake}}"
    if [[ -d "$FLAKE_RAW" ]]; then
      if [[ "$FLAKE_RAW" == "/etc/nixos" ]]; then
        # Keep /etc/nixos as a standard flake ref (symlink-friendly).
        FLAKE_REF="$FLAKE_RAW"
      else
        # For local dev paths, include uncommitted files via path:.
        FLAKE_REF="path:$FLAKE_RAW"
      fi
    else
      FLAKE_REF="$FLAKE_RAW"
    fi
    HOST="''${CONFIG_HOST:-${defaultHost}}"

    if [[ $# -gt 0 ]]; then
      case "$1" in
        l|pc|work)
          HOST="$1"
          shift
          ;;
      esac
    fi

    preflight_fs_guard "$HOST"
    nix flake update --flake "$FLAKE_RAW"
    sudo nixos-rebuild switch --flake "''${FLAKE_REF}#''${HOST}"
  '';

  buildall = pkgs.writeShellScriptBin "buildall" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    export PATH=${scriptPath}:$PATH

    info()  { printf "\033[1;34m[INFO]\033[0m %s\n"  "$*"; }
    warn()  { printf "\033[1;33m[WARN]\033[0m %s\n"  "$*"; }
    error() { printf "\033[1;31m[ERR ]\033[0m %s\n"  "$*" >&2; }

    git_repo() {
      local dir="$1"
      shift
      if [[ -w "$dir/.git" || -w "$dir/.git/config" ]]; then
        git -C "$dir" "$@"
      elif [[ -n "''${SSH_AUTH_SOCK:-}" ]]; then
        sudo env SSH_AUTH_SOCK="''${SSH_AUTH_SOCK}" git -C "$dir" "$@"
      else
        sudo git -C "$dir" "$@"
      fi
    }

    sync_flake_repo() {
      local dir="$1"

      if [[ ! -d "$dir" ]]; then
        warn "Flake path is not a local directory; skipping git pull for $dir."
        return 0
      fi

      if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        warn "Flake path is not a git repo; skipping git pull for $dir."
        return 0
      fi

      if ! git_repo "$dir" remote get-url origin >/dev/null 2>&1; then
        warn "No 'origin' remote in $dir; skipping git pull."
        return 0
      fi

      if ! git_repo "$dir" symbolic-ref -q HEAD >/dev/null 2>&1; then
        warn "Detached HEAD in $dir; skipping git pull."
        return 0
      fi

      local branch upstream original_head stash_ref restore_ref pull_out pop_out
      branch="$(git_repo "$dir" rev-parse --abbrev-ref HEAD)"

      if ! upstream="$(git_repo "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
        warn "Branch '$branch' in $dir has no upstream; skipping git pull."
        return 0
      fi

      original_head="$(git_repo "$dir" rev-parse HEAD)"
      stash_ref=""
      restore_ref="$original_head"

      if [[ -n "$(git_repo "$dir" status --porcelain=v1 --untracked-files=all)" ]]; then
        info "Stashing local changes in $dir before pulling $upstream..."
        git_repo "$dir" stash push --include-untracked --message "buildall-pre-pull $(date -Iseconds)" >/dev/null
        stash_ref="$(git_repo "$dir" rev-parse -q --verify refs/stash)"
      fi

      info "Pulling latest changes for '$branch' from '$upstream'..."
      if ! pull_out="$(git_repo "$dir" pull --rebase 2>&1)"; then
        printf '%s\n' "$pull_out" >&2
        if git_repo "$dir" rev-parse -q --verify REBASE_HEAD >/dev/null 2>&1; then
          warn "Pull hit a rebase conflict; aborting pull."
          git_repo "$dir" rebase --abort >/dev/null
        fi
        if [[ -n "$stash_ref" ]]; then
          info "Restoring stashed local changes after failed pull..."
          git_repo "$dir" stash apply --index "$stash_ref" >/dev/null
          git_repo "$dir" stash drop "$stash_ref" >/dev/null || true
        fi
        error "Git pull failed for $dir. Build cancelled."
        return 1
      fi

      if [[ -n "$pull_out" ]]; then
        printf '%s\n' "$pull_out"
      fi

      if [[ -n "$(git_repo "$dir" diff --name-only --diff-filter=U)" ]]; then
        error "Pull left unresolved conflicts in $dir. Cancelling pull."
        git_repo "$dir" reset --merge "$restore_ref" >/dev/null
        if [[ -n "$stash_ref" ]]; then
          info "Restoring stashed local changes after cancelling pull..."
          git_repo "$dir" stash apply --index "$stash_ref" >/dev/null
          git_repo "$dir" stash drop "$stash_ref" >/dev/null || true
        fi
        return 1
      fi

      if [[ -n "$stash_ref" ]]; then
        info "Restoring stashed local changes after pull..."
        if ! pop_out="$(git_repo "$dir" stash pop --index 2>&1)"; then
          printf '%s\n' "$pop_out" >&2
          warn "Local changes conflict with the pulled state; cancelling pull."
          git_repo "$dir" reset --merge "$restore_ref" >/dev/null
          if git_repo "$dir" rev-parse -q --verify "$stash_ref" >/dev/null 2>&1; then
            git_repo "$dir" stash apply --index "$stash_ref" >/dev/null
            git_repo "$dir" stash drop "$stash_ref" >/dev/null || true
          fi
          error "Git pull would conflict with local changes in $dir. Build cancelled."
          return 1
        fi
        if [[ -n "$pop_out" ]]; then
          printf '%s\n' "$pop_out"
        fi
      fi
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

      if ! root_dev="$(nix eval --raw "$root_attr" 2>/dev/null)"; then
        error "Preflight failed: missing fileSystems.\"/\".device for host '$host'."
        return 1
      fi

      if ! boot_dev="$(nix eval --raw "$boot_attr" 2>/dev/null)"; then
        error "Preflight failed: missing fileSystems.\"/boot\".device for host '$host'."
        return 1
      fi

      check_fs_match "/" "$root_dev" "root"
      check_fs_match "/boot" "$boot_dev" "boot"
    }

    FLAKE_RAW="''${CONFIG_FLAKE:-${defaultFlake}}"
    if [[ -d "$FLAKE_RAW" ]]; then
      if [[ "$FLAKE_RAW" == "/etc/nixos" ]]; then
        # Keep /etc/nixos as a standard flake ref (symlink-friendly).
        FLAKE_REF="$FLAKE_RAW"
      else
        # For local dev paths, include uncommitted files via path:.
        FLAKE_REF="path:$FLAKE_RAW"
      fi
    else
      FLAKE_REF="$FLAKE_RAW"
    fi
    usage() {
      echo "Usage: buildall <pc|l|work> [commit-message...]" >&2
      exit 2
    }

    if [[ $# -lt 1 ]]; then
      usage
    fi

    case "$1" in
      pc|l|work)
        HOST="$1"
        shift
        ;;
      *)
        usage
        ;;
    esac

    sync_flake_repo "$FLAKE_RAW"

    if ! nix eval --raw "''${FLAKE_REF}#nixosConfigurations.''${HOST}.config.networking.hostName" >/dev/null 2>&1; then
      echo "Host '$HOST' is not defined in this flake." >&2
      exit 1
    fi

    MSG="''${*:-update: $(date -Iseconds)}"

    preflight_fs_guard "$HOST"
    nix flake update --flake "$FLAKE_RAW"
    sudo nixos-rebuild switch --flake "''${FLAKE_REF}#''${HOST}"
    pushconfigs "$MSG"
  '';

  pushonly = pkgs.writeShellScriptBin "pushonly" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    export PATH=${scriptPath}:$PATH
    exec pushconfigs "''${1:-}"
  '';
in
{
  home.packages = [
    buildall
    flakeonly
    pushonly
    pushConfigs
  ];
}
