{ lib, pkgs, ... }:
let
  firefoxDesktop = "firefox.desktop";
  # TEMPORARY WORKAROUND: Firefox 153 corrupts browser chrome under native
  # Wayland on this host. Remove this wrapper after the upstream regression is
  # fixed and native Wayland has been verified on the work host.
  # Upstream: https://bugzilla.mozilla.org/show_bug.cgi?id=2049922
  firefoxX11 = pkgs.symlinkJoin {
    name = "firefox-x11-${pkgs.firefox.version}";
    paths = [ pkgs.firefox ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/firefox" \
        --set MOZ_ENABLE_WAYLAND 0
    '';
  };
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
    firefoxX11
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
