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
    pkgs.jq
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

  syncNoctalia = pkgs.writeShellScriptBin "syncnoctalia" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    export PATH=${scriptPath}:$PATH

    info()  { printf "\033[1;34m[INFO]\033[0m %s\n"  "$*"; }
    warn()  { printf "\033[1;33m[WARN]\033[0m %s\n"  "$*"; }
    error() { printf "\033[1;31m[ERR ]\033[0m %s\n"  "$*" >&2; }

    choose_source_file() {
      local live="$1"
      local backup="''${live}.hm-back"

      if [[ -e "$live" && ! -L "$live" ]]; then
        printf '%s\n' "$live"
        return 0
      fi

      if [[ -e "$backup" && ( ! -e "$live" || "$backup" -nt "$live" ) ]]; then
        printf '%s\n' "$backup"
        return 0
      fi

      if [[ -e "$live" ]]; then
        printf '%s\n' "$live"
        return 0
      fi

      if [[ -e "$backup" ]]; then
        printf '%s\n' "$backup"
        return 0
      fi

      return 1
    }

    HOST="''${1:-''${CONFIG_HOST:-${defaultHost}}}"
    FLAKE_RAW="''${CONFIG_FLAKE:-${defaultFlake}}"

    REPO_ROOT="$FLAKE_RAW"
    if [[ "$REPO_ROOT" == path:* ]]; then
      REPO_ROOT="''${REPO_ROOT#path:}"
    fi
    if [[ -d "$REPO_ROOT" ]]; then
      REPO_ROOT="$(readlink -f "$REPO_ROOT" 2>/dev/null || printf '%s' "$REPO_ROOT")"
    fi

    TARGET_DIR="$REPO_ROOT/home/modules/niri/noctalia"
    SOURCE_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/noctalia"

    if [[ ! -d "$TARGET_DIR" ]]; then
      error "No Noctalia module directory found at: $TARGET_DIR"
      exit 1
    fi

    if [[ ! -d "$SOURCE_DIR" ]]; then
      error "No Noctalia runtime directory found at: $SOURCE_DIR"
      exit 1
    fi

    SETTINGS_SRC="$(choose_source_file "$SOURCE_DIR/settings.json" || true)"
    if [[ -z "$SETTINGS_SRC" ]]; then
      error "Could not find settings.json in $SOURCE_DIR or settings.json.hm-back."
      exit 1
    fi

    SETTINGS_DST="$TARGET_DIR/settings.json"
    SETTINGS_TMP="$(mktemp)"

    if [[ "$HOST" == "pc" || "$HOST" == "l" ]]; then
      jq -s '
        .[0] * (.[1] | del(
          .bar.monitors,
          .dock.monitors,
          .desktopWidgets.monitorWidgets,
          .general.avatarImage,
          .wallpaper.directory,
          .wallpaper.setWallpaperOnAllMonitors,
          .wallpaper.enableMultiMonitorDirectories
        ))
      ' "$SETTINGS_DST" "$SETTINGS_SRC" > "$SETTINGS_TMP"
      info "Synced settings.json from $SETTINGS_SRC (preserving host-specific keys for $HOST)."
    else
      jq . "$SETTINGS_SRC" > "$SETTINGS_TMP"
      info "Synced settings.json from $SETTINGS_SRC."
    fi
    mv "$SETTINGS_TMP" "$SETTINGS_DST"

    COLORS_SRC="$(choose_source_file "$SOURCE_DIR/colors.json" || true)"
    if [[ -n "$COLORS_SRC" ]]; then
      COLORS_DST="$TARGET_DIR/colors.json"
      COLORS_TMP="$(mktemp)"
      jq . "$COLORS_SRC" > "$COLORS_TMP"
      mv "$COLORS_TMP" "$COLORS_DST"
      info "Synced colors.json from $COLORS_SRC."
    else
      warn "No colors.json found in $SOURCE_DIR (or colors.json.hm-back); skipping."
    fi

    COLORSCHEMES_SRC_DIR="$SOURCE_DIR/colorschemes"
    COLORSCHEMES_DST_DIR="$TARGET_DIR/colorschemes"
    if [[ -d "$COLORSCHEMES_SRC_DIR" ]]; then
      while IFS= read -r -d "" scheme_src; do
        rel_path="''${scheme_src#$COLORSCHEMES_SRC_DIR/}"
        scheme_dst="$COLORSCHEMES_DST_DIR/$rel_path"
        mkdir -p "$(dirname "$scheme_dst")"

        if [[ "$scheme_src" == *.json ]]; then
          scheme_tmp="$(mktemp)"
          jq . "$scheme_src" > "$scheme_tmp"
          mv "$scheme_tmp" "$scheme_dst"
        else
          cp -f "$scheme_src" "$scheme_dst"
        fi
        info "Synced colorschemes/$rel_path."
      done < <(find "$COLORSCHEMES_SRC_DIR" -type f ! -name '*.hm-back' -print0)

      while IFS= read -r -d "" scheme_dst; do
        rel_path="''${scheme_dst#$COLORSCHEMES_DST_DIR/}"
        if [[ ! -f "$COLORSCHEMES_SRC_DIR/$rel_path" ]]; then
          rm -f "$scheme_dst"
          info "Removed stale colorschemes/$rel_path."
        fi
      done < <(find "$COLORSCHEMES_DST_DIR" -type f -print0)

      while IFS= read -r -d "" scheme_dir; do
        rmdir "$scheme_dir" 2>/dev/null || true
      done < <(find "$COLORSCHEMES_DST_DIR" -depth -type d -empty -print0)
    else
      warn "No colorschemes directory found in $COLORSCHEMES_SRC_DIR; skipping."
    fi

    PLUGINS_SRC="$(choose_source_file "$SOURCE_DIR/plugins.json" || true)"
    if [[ -n "$PLUGINS_SRC" ]]; then
      PLUGINS_DST="$TARGET_DIR/plugins.json"
      PLUGINS_TMP="$(mktemp)"
      jq . "$PLUGINS_SRC" > "$PLUGINS_TMP"
      mv "$PLUGINS_TMP" "$PLUGINS_DST"
      info "Synced plugins.json from $PLUGINS_SRC."
    else
      warn "No plugins.json found in $SOURCE_DIR (or plugins.json.hm-back); skipping."
    fi

    PLUGIN_SETTINGS_SRC_DIR="$SOURCE_DIR/plugins"
    PLUGIN_SETTINGS_DST_DIR="$TARGET_DIR/plugins"
    if [[ -d "$PLUGIN_SETTINGS_SRC_DIR" ]]; then
      while IFS= read -r rel_path; do
        plugin_src="$(choose_source_file "$PLUGIN_SETTINGS_SRC_DIR/$rel_path" || true)"
        if [[ -z "$plugin_src" ]]; then
          continue
        fi

        plugin_dst="$PLUGIN_SETTINGS_DST_DIR/$rel_path"
        mkdir -p "$(dirname "$plugin_dst")"
        plugin_tmp="$(mktemp)"
        jq . "$plugin_src" > "$plugin_tmp"
        mv "$plugin_tmp" "$plugin_dst"
        info "Synced plugins/$rel_path."
      done < <(
        find "$PLUGIN_SETTINGS_SRC_DIR" -type f \( -name 'settings.json' -o -name 'settings.json.hm-back' \) -printf '%P\n' \
          | sed 's/\.hm-back$//' \
          | sort -u
      )
    else
      warn "No plugins directory found in $PLUGIN_SETTINGS_SRC_DIR; skipping plugin settings sync."
    fi

    info "Noctalia sync complete."
  '';

  buildall = pkgs.writeShellScriptBin "buildall" ''
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
    usage() {
      echo "Usage: buildall [--sync-noctalia] <pc|l|work> [commit-message...]" >&2
      exit 2
    }

    SYNC_NOCTALIA=0
    HOST=""

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --sync-noctalia)
          SYNC_NOCTALIA=1
          shift
          ;;
        pc|l|work)
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

    if ! nix eval --raw "''${FLAKE_REF}#nixosConfigurations.''${HOST}.config.networking.hostName" >/dev/null 2>&1; then
      echo "Host '$HOST' is not defined in this flake." >&2
      exit 1
    fi

    MSG="''${*:-update: $(date -Iseconds)}"

    if [[ "$SYNC_NOCTALIA" -eq 1 ]]; then
      syncnoctalia "$HOST"
    fi

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
    syncNoctalia
  ];
}
