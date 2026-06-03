{ ... }:
{
  programs.fish = {
    enable = true;

    functions.fish_greeting = ''
      set -l green (set_color 8ccf7e)
      set -l moss (set_color 6f8f5f)
      set -l bark (set_color a58f6f)
      set -l dim (set_color 6b7f6a)
      set -l normal (set_color normal)

      set -l where (prompt_pwd)
      set -l branch

      if command git rev-parse --is-inside-work-tree >/dev/null 2>&1
        set branch (command git branch --show-current 2>/dev/null)

        if test -z "$branch"
          set branch (command git rev-parse --short HEAD 2>/dev/null)
        end
      end

      echo
      printf '%s%s%s%s\n' "$green" '     /\      ' "$moss" 'forest shell'
      printf '%s%s%s%s\n' "$green" '  /\ /  \    ' "$dim" 'quiet terminal, useful shell'
      printf '%s  path  %s%s%s\n' "$bark" "$normal" "$where" "$normal"

      if test -n "$branch"
        printf '%s  git   %s%s%s\n' "$green" "$normal" "$branch" "$normal"
      end

      if test -n "$IN_NIX_SHELL"
        printf '%s  nix   %s%s%s\n' "$moss" "$normal" "$IN_NIX_SHELL" "$normal"
      end

      printf '%s  hint  %s%s%s\n' "$dim" "$normal" 'configure by friction, keep what helps' "$normal"
      echo
    '';
  };

  # aliases
  # abbreviations
  # functions
  # prompt
}
