{ pkgs, ... }: {
  home.packages = with pkgs; [
    wget
    qownnotes
    nodejs
    dbeaver-bin
    gimp-with-plugins
    libreoffice
    php
    clinfo
    freshfetch
    ffmpeg
    stow
    gcc
    gnumake
    unzip
    ripgrep
    luarocks-nix
    lua
    lua51Packages.lz-n
    kitty
    python3
    audacity
    #prismlauncher
    orca-slicer
    easyeffects
    yazi
    tmux
    neovim
    dislocker
    ddrescue
    cryptsetup
    bottles
  ];
}

