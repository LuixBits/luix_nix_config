{ config, lib, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "git" ];
    };
    history = {
      path = "${config.xdg.dataHome}/zsh/history";
      size = 10000;
      save = 10000;
      share = true;
    };
    shellAliases = {
      ll = "ls -alh";
      gs = "git status -sb";
    };
    initExtraFirst = ''
      typeset -U path cdpath fpath manpath
      for profile in ''${(z)NIX_PROFILES}; do
        fpath+=("$profile/share/zsh/site-functions" "$profile/share/zsh/$ZSH_VERSION/functions" "$profile/share/zsh/vendor-completions")
      done
    '';
    initExtra = ''
      setopt HIST_FCNTL_LOCK
      unsetopt APPEND_HISTORY
      setopt HIST_IGNORE_DUPS
      unsetopt HIST_IGNORE_ALL_DUPS
      unsetopt HIST_SAVE_NO_DUPS
      unsetopt HIST_FIND_NO_DUPS
      setopt HIST_IGNORE_SPACE
      unsetopt HIST_EXPIRE_DUPS_FIRST
      unsetopt EXTENDED_HISTORY

      if [[ -n "$KITTY_INSTALLATION_DIR" ]]; then
        export KITTY_SHELL_INTEGRATION="no-rc"
        autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
        kitty-integration
        unfunction kitty-integration
      fi
    '';
  };

  # ensure the managed .zshrc replaces any pre-existing file
  home.file.".zshrc".force = lib.mkDefault true;
}
