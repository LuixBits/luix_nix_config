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
    gnome-disk-utility
    gimp-with-plugins
    libreoffice
    nautilus
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

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
    };
  };
}
