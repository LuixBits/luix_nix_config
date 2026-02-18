{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    userName = "Luix";
    userEmail = "luix@users.noreply.github.com";
  };
  programs.tmux.enable = true;

  home.packages = with pkgs; [
    yazi
  ];
}
