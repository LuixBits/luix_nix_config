{ pkgs, ... }:
{
  programs.git.enable = true;
  programs.tmux.enable = true;

  home.packages = with pkgs; [
    yazi
  ];
}
