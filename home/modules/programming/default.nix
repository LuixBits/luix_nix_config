{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    profiles.default.userSettings = {
      "terminal.integrated.defaultProfile.linux" = "fish";
      "terminal.integrated.profiles.linux".fish.path = "${pkgs.fish}/bin/fish";
    };
  };

  home.packages = with pkgs; [
    dbeaver-bin
    gcc
    gnumake
    jdk
    lua
    lua51Packages.lz-n
    luarocks-nix
    nodejs
    pnpm
    php
    python3
    whois
    dig
    nmap
    opencode
  ];
}
