{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Core utilities
    clinfo
    cliphist
    freshfetch
    ripgrep
    stow
    unzip
    wget
    wl-clipboard

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
    vlc
    kdePackages.okular


    # Media tools
    audacity
    ffmpeg
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
