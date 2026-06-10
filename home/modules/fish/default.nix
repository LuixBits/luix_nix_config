{ lib, ... }:
let
  kanagawa = import ../theme/kanagawa.nix;
  c = kanagawa.palette;
  hex = color: lib.removePrefix "#" color;
in
{
  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      set -l foreground ${hex c.fujiWhite} normal
      set -l selection ${hex c.waveBlue2} brcyan
      set -l comment ${hex c.fujiGray} brblack
      set -l red ${hex c.autumnRed} red
      set -l orange ${hex c.roninYellow} brred
      set -l yellow ${hex c.boatYellow2} yellow
      set -l green ${hex c.autumnGreen} green
      set -l purple ${hex c.oniViolet} magenta
      set -l cyan ${hex c.waveAqua2} cyan
      set -l pink ${hex c.sakuraPink} brmagenta

      set -g fish_color_normal $foreground
      set -g fish_color_command $cyan
      set -g fish_color_keyword $pink
      set -g fish_color_quote $yellow
      set -g fish_color_redirection $foreground
      set -g fish_color_end $orange
      set -g fish_color_error $red
      set -g fish_color_param $purple
      set -g fish_color_comment $comment
      set -g fish_color_selection --background=$selection
      set -g fish_color_search_match --background=$selection
      set -g fish_color_operator $green
      set -g fish_color_escape $pink
      set -g fish_color_autosuggestion $comment

      set -g fish_pager_color_progress $comment
      set -g fish_pager_color_prefix $cyan
      set -g fish_pager_color_completion $foreground
      set -g fish_pager_color_description $comment
    '';

    functions.fish_greeting = ''
      set -l pine (set_color ${hex c.autumnGreen})
      set -l leaf (set_color ${hex c.springGreen})
      set -l moss (set_color ${hex c.waveAqua2})
      set -l bark (set_color ${hex c.boatYellow2})
      set -l mist (set_color ${hex c.fujiGray})
      set -l hello (set_color ${hex c.fujiWhite})
      set -l normal (set_color normal)

      echo
      printf '%s%s%s\n' "$pine" '       /\        /\        /\       ' "$normal"
      printf '%s%s%s\n' "$leaf" '      /  \  /\  /  \  /\  /  \      ' "$normal"
      printf '%s%s%s\n' "$pine" '     /____\/__\/____\/__\/____\     ' "$normal"
      printf '%s      ||    ||   %shello%s   ||    ||%s\n' "$bark" "$hello" "$bark" "$normal"
      printf '%s%s%s\n' "$moss" '   /\ ||        /\        || /\    ' "$normal"
      printf '%s%s%s\n' "$pine" '  /__\||       /__\       ||/__\   ' "$normal"
      printf '%s%s%s\n' "$mist" '       ~~~  ~~~  ~~  ~~~  ~~~       ' "$normal"
      echo
    '';

    shellAliases = {
      ll = "ls -lah";
      la = "ls -A";
    };

    shellAbbrs = {
      # config jumps
      cconf = "cd ~/luix_nix_config";
      cmods = "cd ~/luix_nix_config/home/modules";
      chosts = "cd ~/luix_nix_config/hosts";

      # video / motion canvas
      cmc = "cd ~/Documents/motion-canvas-next-video";
      cscenes = "cd ~/Documents/motion-canvas-next-video/src/scenes";

      # git
      gs = "git status --short --branch";
      gd = "git diff";
      gds = "git diff --staged";
      gl = "git log --oneline --decorate --graph -20";
      gaa = "git add -A";
      gc = "git commit";
      gp = "git push";

      # nix, but not replacing buildall
      nfc = "nix flake check";
      nfu = "nix flake update";
      nd = "nix develop";
    };

    functions = {
      conf = ''
        cd ~/luix_nix_config; or return
        nvim .
      '';

      fishconf = ''
        cd ~/luix_nix_config/home/modules/fish; or return
        nvim default.nix
      '';

      kittyconf = ''
        cd ~/luix_nix_config/home/modules/kitty; or return
        nvim default.nix
      '';

      mod = ''
        if test -z "$argv[1]"
          cd ~/luix_nix_config/home/modules; or return
          nvim .
          return
        end

        set -l module ~/luix_nix_config/home/modules/$argv[1]

        if test -f "$module/default.nix"
          cd "$module"; or return
          nvim default.nix
        else
          echo "module not found: $argv[1]"
        end
      '';

      hostconf = ''
        if test -z "$argv[1]"
          cd ~/luix_nix_config/hosts; or return
          nvim .
          return
        end

        set -l host ~/luix_nix_config/hosts/$argv[1]

        if test -f "$host/default.nix"
          cd "$host"; or return
          nvim default.nix
        else
          echo "host not found: $argv[1]"
        end
      '';

      groot = ''
        set -l root (git rev-parse --show-toplevel 2>/dev/null)

        if test -n "$root"
          cd "$root"
        else
          echo "not inside a git repo"
        end
      '';

      fish_prompt = ''
        set -l last_status $status

        set -l pine (set_color ${hex c.autumnGreen})
        set -l leaf (set_color ${hex c.springGreen})
        set -l moss (set_color ${hex c.springBlue})
        set -l bark (set_color ${hex c.surimiOrange})
        set -l red (set_color ${hex c.samuraiRed})
        set -l normal (set_color normal)

        printf '%s%s%s' "$moss" (prompt_pwd) "$normal"

        if command git rev-parse --is-inside-work-tree >/dev/null 2>&1
          set -l branch (command git branch --show-current 2>/dev/null)

          if test -z "$branch"
            set branch (command git rev-parse --short HEAD 2>/dev/null)
          end

          set -l dirty

          if not command git diff --quiet --ignore-submodules -- 2>/dev/null
            set dirty "$dirty*"
          end

          if not command git diff --cached --quiet --ignore-submodules -- 2>/dev/null
            set dirty "$dirty+"
          end

          set -l untracked (command git ls-files --others --exclude-standard 2>/dev/null | head -n 1)
          if test -n "$untracked"
            set dirty "$dirty?"
          end

          if test -n "$branch"
            printf ' %s%s%s%s' "$leaf" "$branch" "$dirty" "$normal"
          end
        end

        if test -n "$IN_NIX_SHELL"
          printf ' %s[%s]%s' "$bark" "nix:$IN_NIX_SHELL" "$normal"
        end

        if test $last_status -ne 0
          printf ' %s[%s]%s' "$red" "$last_status" "$normal"
        end

        printf '\n'

        if test $last_status -ne 0
          printf '%sx%s ' "$red" "$normal"
        else
          printf '%s>%s ' "$pine" "$normal"
        end
      '';

    };
  };
}
