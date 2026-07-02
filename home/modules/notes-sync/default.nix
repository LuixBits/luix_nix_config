{ config, lib, pkgs, ... }:
let
  notesDir = "${config.home.homeDirectory}/notes";
  notesRemote = "git@github.com:devluixos/notes.git";
  notesRepo = "devluixos/notes";
  notesBranch = "main";

  scriptPath = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.gh
    pkgs.git
    pkgs.gnugrep
    pkgs.openssh
    pkgs.util-linux
  ];

  notesGitignore = pkgs.writeText "notes-gitignore" ''
    *.swp
    *.swo
    *~
    .DS_Store
    .direnv/
    .stversions/
    .sync-conflict-*
    *.sync-conflict-*
  '';

  common = ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    export PATH=${scriptPath}:$PATH

    info() { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
    warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*" >&2; }
    error() { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*" >&2; }

    NOTES_DIR="''${NOTES_DIR:-${notesDir}}"
    NOTES_REMOTE="''${NOTES_REMOTE:-${notesRemote}}"
    NOTES_REPO="''${NOTES_REPO:-${notesRepo}}"
    NOTES_BRANCH="''${NOTES_BRANCH:-${notesBranch}}"
    LOCK_FILE="''${NOTES_LOCK_FILE:-''${XDG_RUNTIME_DIR:-/tmp}/notes-sync-''${USER:-user}.lock}"

    with_lock() {
      exec 9>"$LOCK_FILE"
      if ! flock -n 9; then
        warn "Another notes sync is already running."
        exit 0
      fi
    }

    network_fail() {
      warn "$*"
      if [[ "''${NOTES_SYNC_NON_FATAL_NETWORK:-0}" == "1" ]]; then
        exit 0
      fi
      exit 1
    }

    ensure_notes_dir() {
      mkdir -p "$NOTES_DIR"
    }

    ensure_gitignore() {
      local gitignore="$NOTES_DIR/.gitignore"
      if [[ -e "$gitignore" ]]; then
        return 0
      fi

      install -m 0644 "${notesGitignore}" "$gitignore"
    }

    ensure_origin() {
      local current_remote
      if current_remote="$(git remote get-url origin 2>/dev/null)"; then
        if [[ "$current_remote" != "$NOTES_REMOTE" ]]; then
          warn "Updating notes origin remote to $NOTES_REMOTE."
          git remote set-url origin "$NOTES_REMOTE"
        fi
      else
        git remote add origin "$NOTES_REMOTE"
      fi
    }

    ensure_github_repo() {
      if gh repo view "$NOTES_REPO" >/dev/null 2>&1; then
        return 0
      fi

      info "Creating private GitHub repo $NOTES_REPO..."
      gh repo create "$NOTES_REPO" --private --description "Private Neorg notes"
    }

    ensure_repo() {
      ensure_notes_dir
      ensure_gitignore

      if [[ ! -d "$NOTES_DIR/.git" ]]; then
        if [[ "''${NOTES_SYNC_SKIP_UNINITIALIZED:-0}" == "1" ]]; then
          warn "Notes repo is not initialized at $NOTES_DIR. Skipping automatic sync."
          exit 0
        fi

        info "Initializing notes Git repo in $NOTES_DIR..."
        git -C "$NOTES_DIR" init -b "$NOTES_BRANCH"
      fi

      cd "$NOTES_DIR"

      if [[ -d .git/rebase-merge || -d .git/rebase-apply ]] || git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
        error "A merge or rebase is already in progress in $NOTES_DIR. Resolve it before syncing."
        exit 1
      fi

      if [[ -n "$(git diff --name-only --diff-filter=U)" ]]; then
        error "Unresolved merge conflicts exist in $NOTES_DIR. Resolve them before syncing."
        exit 1
      fi

      local current_branch
      current_branch="$(git branch --show-current 2>/dev/null || true)"
      if [[ -n "$current_branch" && "$current_branch" != "$NOTES_BRANCH" ]]; then
        error "Notes repo is on branch '$current_branch', expected '$NOTES_BRANCH'."
        exit 1
      fi

      ensure_origin
      ensure_github_repo
      ensure_gitignore
    }

    has_head() {
      git rev-parse --verify HEAD >/dev/null 2>&1
    }

    commit_local_changes() {
      if [[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]]; then
        return 0
      fi

      git add -A
      if git diff --cached --quiet; then
        return 0
      fi

      local host timestamp
      host="$(cat /proc/sys/kernel/hostname 2>/dev/null || printf 'unknown')"
      timestamp="$(date -Iseconds)"
      git commit -m "notes: sync $host $timestamp"
    }

    fetch_origin() {
      git fetch origin --prune
    }

    remote_branch_exists() {
      git show-ref --verify --quiet "refs/remotes/origin/$NOTES_BRANCH"
    }

    rebase_remote_if_present() {
      if ! remote_branch_exists; then
        return 0
      fi

      if has_head; then
        git rebase "origin/$NOTES_BRANCH"
      else
        error "Remote branch origin/$NOTES_BRANCH exists, but local repo has no commits. Clone or merge manually."
        exit 1
      fi
    }

    push_with_retry() {
      if git push -u origin "$NOTES_BRANCH"; then
        return 0
      fi

      warn "Initial push failed. Fetching/rebasing once before retry..."
      if ! fetch_origin; then
        network_fail "Could not fetch origin after push failure. Will retry on the next sync."
      fi
      rebase_remote_if_present
      git push -u origin "$NOTES_BRANCH" || network_fail "Could not push notes to origin."
    }
  '';

  notesPull = pkgs.writeShellScriptBin "notes-pull" ''
    ${common}
    with_lock
    ensure_repo
    if ! fetch_origin; then
      network_fail "Could not fetch origin. Will retry on the next sync."
    fi
    rebase_remote_if_present
    info "Notes pull complete."
  '';

  notesPush = pkgs.writeShellScriptBin "notes-push" ''
    ${common}
    with_lock
    ensure_repo
    commit_local_changes
    push_with_retry
    info "Notes push complete."
  '';

  notesSync = pkgs.writeShellScriptBin "notes-sync" ''
    ${common}
    with_lock
    ensure_repo
    commit_local_changes
    if ! fetch_origin; then
      network_fail "Could not fetch origin. Local notes are committed; will retry remote sync later."
    fi
    rebase_remote_if_present
    commit_local_changes
    push_with_retry
    info "Notes sync complete."
  '';
in
{
  options.luix.notesSync.commands = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    internal = true;
    description = "Absolute command paths for the Neorg notes Git keymaps.";
  };

  config = {
    luix.notesSync.commands = {
      pull = "${notesPull}/bin/notes-pull";
      push = "${notesPush}/bin/notes-push";
      sync = "${notesSync}/bin/notes-sync";
    };

    home.packages = [
      pkgs.lazygit
    ];

    home.activation.ensureNotesSyncGitignore = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      notes_dir="${notesDir}"
      run mkdir -p "$notes_dir"
      if [ ! -e "$notes_dir/.gitignore" ]; then
        run install -m 0644 "${notesGitignore}" "$notes_dir/.gitignore"
      fi
    '';

    systemd.user.services.notes-sync = {
      Unit.Description = "Sync Neorg notes";
      Service = {
        Type = "oneshot";
        ExecStart = "${notesSync}/bin/notes-sync";
        Environment = [
          "NOTES_DIR=${notesDir}"
          "NOTES_REMOTE=${notesRemote}"
          "NOTES_REPO=${notesRepo}"
          "NOTES_BRANCH=${notesBranch}"
          "NOTES_SYNC_NON_FATAL_NETWORK=1"
          "NOTES_SYNC_SKIP_UNINITIALIZED=1"
        ];
      };
    };

    systemd.user.timers.notes-sync = {
      Unit.Description = "Automatically sync Neorg notes";
      Timer = {
        OnStartupSec = "2min";
        OnUnitActiveSec = "10min";
        Persistent = true;
        Unit = "notes-sync.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
