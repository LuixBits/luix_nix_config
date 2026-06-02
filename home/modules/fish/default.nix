{ ... }:
{
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting

      set -g fish_color_normal c5c9c5
      set -g fish_color_command 8a9a7b
      set -g fish_color_keyword c4b28a
      set -g fish_color_quote c8c093
      set -g fish_color_redirection 8ba4b0
      set -g fish_color_end 8ea4a2
      set -g fish_color_error c4746e
      set -g fish_color_param c5c9c5
      set -g fish_color_comment 625e5a
      set -g fish_color_selection --background=282727
      set -g fish_color_search_match --background=393836
      set -g fish_color_autosuggestion 625e5a
      set -g fish_color_valid_path --underline
      set -g fish_color_operator 8ea4a2
      set -g fish_color_escape a292a3
      set -g fish_color_cwd c4b28a
      set -g fish_color_cwd_root c4746e
      set -g fish_color_host 8ba4b0
      set -g fish_color_user c5c9c5
    '';
    functions = {
      __luix_kanagawa_git = ''
        command git rev-parse --is-inside-work-tree >/dev/null 2>&1; or return

        set -l branch (command git symbolic-ref --short HEAD 2>/dev/null; or command git rev-parse --short HEAD 2>/dev/null)
        test -n "$branch"; or return

        set -l dirty_state (command git status --porcelain --untracked-files=normal 2>/dev/null)
        set -l dirty
        if test -n "$dirty_state"
          set dirty '*'
        end

        set_color 625e5a
        printf ' on '
        set_color 8a9a7b
        printf ' %s%s' $branch $dirty
      '';

      fish_prompt = ''
        set -l last_status $status

        set_color 8ea4a2
        printf '╭─'
        set_color c5c9c5
        printf '%s' $USER
        set_color 625e5a
        printf '@'
        set_color 8ba4b0
        printf '%s' (hostname -s)
        set_color 625e5a
        printf ' in '
        set_color c4b28a
        printf '%s' (prompt_pwd)

        __luix_kanagawa_git

        if test -n "$IN_NIX_SHELL"
          set_color a292a3
          printf ' nix'
        end

        if test $last_status -ne 0
          set_color c4746e
          printf ' [%s]' $last_status
        end

        printf '\n'
        set_color 8a9a7b
        printf '╰─'
        set_color c8c093
        printf 'λ '
        set_color normal
      '';

      fish_right_prompt = ''
        set -l duration $CMD_DURATION
        if test -z "$duration"; or test $duration -lt 1000
          return
        end

        set_color 625e5a
        printf '%ss' (math --scale=1 "$duration / 1000")
        set_color normal
      '';
    };
  };
}
