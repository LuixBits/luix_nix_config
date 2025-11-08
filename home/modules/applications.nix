{ pkgs, ... }:
{
  home.packages = with pkgs; [
    bottles
    discord
    firefox
    gimp-with-plugins
    libreoffice
    obs-studio
    obsidian
    qownnotes
    steam
  ];
}
