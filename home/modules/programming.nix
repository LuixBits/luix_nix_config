{ pkgs, ... }:
{
  home.packages = with pkgs; [
    dbeaver-bin
    gcc
    gnumake
    jdk
    lua
    lua51Packages.lz-n
    luarocks-nix
    nodejs
    php
    python3
  ];
}
