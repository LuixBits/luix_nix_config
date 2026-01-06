{ pkgs, lib, ... }:
let
  defaultFlake = "/home/luix/luix_nix_config";
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

    FLAKE="''${CONFIG_FLAKE:-${defaultFlake}}"
    HOST="''${CONFIG_HOST:-${defaultHost}}"

    if [[ $# -gt 0 ]]; then
      case "$1" in
        l|pc)
          HOST="$1"
          shift
          ;;
      esac
    fi

    nix flake update --flake "$FLAKE"
    sudo nixos-rebuild switch --flake "''${FLAKE}#''${HOST}"
  '';

  buildall = pkgs.writeShellScriptBin "buildall" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    export PATH=${scriptPath}:$PATH

    FLAKE="''${CONFIG_FLAKE:-${defaultFlake}}"
    HOST="''${CONFIG_HOST:-${defaultHost}}"

    if [[ $# -gt 0 ]]; then
      case "$1" in
        l|pc)
          HOST="$1"
          shift
          ;;
      esac
    fi

    MSG="''${*:-update: $(date -Iseconds)}"

    nix flake update --flake "$FLAKE"
    sudo nixos-rebuild switch --flake "''${FLAKE}#''${HOST}"
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
