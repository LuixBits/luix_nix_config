{ pkgs, ... }:
{
  programs.git.enable = true;
  programs.tmux.enable = true;
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  home.packages = with pkgs; [
    yazi
  ];
}
