{ pkgs, ... }:
{
  home.packages = with pkgs; [
    clinfo
    freshfetch
    ripgrep
    stow
    unzip
    wget
  ];
}
