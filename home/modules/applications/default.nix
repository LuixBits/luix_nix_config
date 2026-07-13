{ lib, pkgs, ... }:
let
  firefoxDesktop = "firefox.desktop";
  firefoxWebHandlers = lib.genAttrs [
    "application/rss+xml"
    "application/xhtml+xml"
    "application/xml"
    "application/vnd.mozilla.xul+xml"
    "text/html"
    "text/xml"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
  ] (_: [ firefoxDesktop ]);
in
{
  home.sessionVariables.BROWSER = "firefox";

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
    qpwgraph
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
    chromaprint
    picard
    termsonic
  ];

  xdg.mimeApps = {
    enable = true;
    associations.added = firefoxWebHandlers;
    defaultApplications = {
      "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
    } // firefoxWebHandlers;
  };
}
