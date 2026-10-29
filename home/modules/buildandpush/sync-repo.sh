# Shared Git-only sync logic. Callers provide info, warn, and error functions.
# Keep recovery refs local: pushconfigs pushes the current branch explicitly.

git_repo() {
  local dir="$1"
  shift
  if [[ -w "$dir/.git" || -w "$dir/.git/config" ]]; then
    git -C "$dir" "$@"
  elif [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
    sudo env SSH_AUTH_SOCK="$SSH_AUTH_SOCK" git -C "$dir" "$@"
  else
    sudo git -C "$dir" "$@"
  fi
}

check_repo_ready() {
  local dir="$1"

  if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 0
  fi

  local git_dir
  git_dir="$(git_repo "$dir" rev-parse --absolute-git-dir)" || return 1
  if [[ -f "$git_dir/MERGE_HEAD" \
    || -d "$git_dir/rebase-merge" \
    || -d "$git_dir/rebase-apply" \
    || -f "$git_dir/CHERRY_PICK_HEAD" \
    || -f "$git_dir/REVERT_HEAD" \
    || -d "$git_dir/sequencer" ]]; then
    error "Repo $dir has an in-progress Git operation. Finish or abort it before running buildall."
    return 1
  fi
  if [[ -n "$(git_repo "$dir" diff --name-only --diff-filter=U)" ]]; then
    error "Repo $dir has unresolved merge conflicts. Resolve them and git add the resolved files before running buildall."
    return 1
  fi
}

check_incoming_paths() {
  local dir="$1" upstream="$2" local_path incoming_path
  local -a local_paths incoming_paths
  # Include ignored files in the collision check, but never put them (possibly
  # credentials or large build outputs) into Git's object database.
  mapfile -d '' -t local_paths < <(git_repo "$dir" ls-files --others -z)
  mapfile -d '' -t incoming_paths < <(git_repo "$dir" diff --no-renames --name-only --diff-filter=A -z HEAD "$upstream")
  for local_path in "${local_paths[@]}"; do
    local_path="${local_path%/}"
    for incoming_path in "${incoming_paths[@]}"; do
      if [[ "$local_path" == "$incoming_path" \
        || "$local_path" == "$incoming_path/"* \
        || "$incoming_path" == "$local_path/"* ]]; then
        error "Incoming '$incoming_path' overlaps local untracked or ignored '$local_path'."
        error "Reconcile or move that local path before retrying. Local files are unchanged; build cancelled."
        return 1
      fi
    done
  done
}

sync_flake_repo() {
  local dir="$1"
  if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    warn "Flake path is not a local Git repo; skipping sync for $dir."
    return 0
  fi
  check_repo_ready "$dir" || return 1

  local git_dir branch upstream remote original_head backup_ref stash_oid previous_stash
  git_dir="$(git_repo "$dir" rev-parse --absolute-git-dir)" || return 1
  if ! branch="$(git_repo "$dir" symbolic-ref --quiet --short HEAD)"; then
    warn "Detached HEAD in $dir; skipping Git sync."
    return 0
  fi
  if ! upstream="$(git_repo "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
    warn "Branch '$branch' in $dir has no upstream; skipping Git sync."
    return 0
  fi
  remote="$(git_repo "$dir" config --get "branch.$branch.remote")" || return 1

  # Network failure must not move HEAD or put the user's edits into a stash.
  info "Fetching '$upstream' before changing local files..."
  if ! git_repo "$dir" fetch "$remote"; then
    error "Fetch failed for $dir. Local files are unchanged; build cancelled."
    return 1
  fi
  check_incoming_paths "$dir" "$upstream" || return 1

  original_head="$(git_repo "$dir" rev-parse HEAD)" || return 1
  backup_ref="refs/buildall-backups/$(date -u +%Y%m%dT%H%M%SZ)-$$-$RANDOM"
  git_repo "$dir" update-ref "$backup_ref/head" "$original_head" || return 1
  info "Recovery snapshot: $backup_ref/head"
  stash_oid=""

  if [[ -n "$(git_repo "$dir" status --porcelain=v1 --untracked-files=all)" ]]; then
    previous_stash="$(git_repo "$dir" rev-parse --verify refs/stash 2>/dev/null || true)"
    info "Saving staged, unstaged, and untracked changes before sync..."
    git_repo "$dir" stash push --include-untracked --message "buildall backup $backup_ref" || return 1
    stash_oid="$(git_repo "$dir" rev-parse --verify refs/stash)" || return 1
    if [[ "$stash_oid" == "$previous_stash" ]]; then
      error "Git could not snapshot the local changes. Sync cancelled."
      return 1
    fi
    git_repo "$dir" update-ref "$backup_ref/worktree" "$stash_oid" || return 1
    info "Local edits saved in $backup_ref/worktree and git stash list. This backup is retained."
  fi

  info "Integrating '$upstream' into '$branch'..."
  # Fetch separately so restoration never depends on another network operation.
  # Disable Git's own autostash: the explicit snapshot above is the recovery copy.
  if ! git_repo "$dir" -c rebase.autoStash=false rebase "$upstream"; then
    if [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" ]]; then
      if ! git_repo "$dir" rebase --abort; then
        error "Could not abort rebase. Recovery files are kept under $backup_ref; build cancelled."
        return 1
      fi
    fi
    if [[ -n "$stash_oid" ]]; then
      if [[ "$(git_repo "$dir" rev-parse HEAD)" != "$original_head" ]]; then
        error "HEAD changed unexpectedly. Local edits remain in $backup_ref/worktree; build cancelled."
        return 1
      fi
      if ! git_repo "$dir" stash apply --index "$stash_oid"; then
        error "Could not fully restore local edits; the complete snapshot is $backup_ref/worktree."
        return 1
      fi
    fi
    error "Git integration failed. Original checkout restored; build cancelled."
    return 1
  fi

  if [[ -n "$stash_oid" ]]; then
    local -a restore_options=()
    if [[ "$(git_repo "$dir" rev-parse HEAD)" == "$original_head" ]]; then
      restore_options+=(--index)
    else
      info "Merging local edits with remote changes. The original staging state remains in the backup."
    fi
    # --index replays the old staged patch verbatim and can fail even when the
    # file contents merge cleanly. On a new HEAD, use Git's three-way merge.
    if ! git_repo "$dir" stash apply "${restore_options[@]}" "$stash_oid"; then
      error "Local edits need conflict resolution. Remote commits and merge results are kept in $dir."
      error "Resolve conflicts, git add the resolved files, then rerun buildall. No rebuild or push was attempted."
      error "All original local edits (including untracked files) remain in $backup_ref/worktree."
      return 1
    fi
  fi
}
