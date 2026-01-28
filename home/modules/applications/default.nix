{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Core utilities
    clinfo
    freshfetch
    ripgrep
    stow
    unzip
    wget

    # Desktop apps
    bottles
    chromium
    discord
    firefox
    gimp-with-plugins
    libreoffice
    obs-studio
    obsidian
    qownnotes
    steam
    vlc
    kdePackages.okular


    # Media tools
    audacity
    easyeffects
    ffmpeg
    handbrake
    orca-slicer
    shotcut
    yt-dlp

    # Music tools
    aonsoku
    beets
    chromaprint
    picard
    termsonic
  ];
}
