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
    gnome-disk-utility
    gimp-with-plugins
    libreoffice
    nautilus
    obs-studio
    obsidian
    qownnotes
    vlc
    wdisplays
    kdePackages.okular


    # Media tools
    audacity
    ffmpeg
    orca-slicer
    yt-dlp

    # Music tools
    aonsoku
    beets
    chromaprint
    picard
    termsonic
  ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
    };
  };
}
