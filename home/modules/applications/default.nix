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
  herdrAdminFirefox = pkgs.writeShellApplication {
    name = "herdr-firefox-admin";
    runtimeInputs = [ firefoxX11 pkgs.coreutils ];
    text = ''
      data_home="''${XDG_DATA_HOME:-$HOME/.local/share}"
      profile_dir="$data_home/luix-browser-profiles/firefox-admin"
      install -d -m 0700 "$profile_dir"

      if [ "$#" -eq 0 ]; then
        set -- about:blank
      fi

      exec firefox \
        --no-remote \
        --profile "$profile_dir" \
        --new-window "$1"
    '';
  };
  herdrNormalChromium = pkgs.writeShellApplication {
    name = "herdr-chromium-normal";
    runtimeInputs = [ pkgs.chromium pkgs.coreutils ];
    text = ''
      data_home="''${XDG_DATA_HOME:-$HOME/.local/share}"
      profile_dir="$data_home/luix-browser-profiles/chromium-normal"
      install -d -m 0700 "$profile_dir"

      if [ "$#" -eq 0 ]; then
        set -- \
          "https://discord.com/app" \
          "https://www.youtube.com/"
      fi

      exec chromium \
        --user-data-dir="$profile_dir" \
        --new-window \
        "$@"
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
    herdrAdminFirefox
    herdrNormalChromium
    gnome-disk-utility
    gimp-with-plugins
    libreoffice
    nautilus
    obs-studio
    obsidian
    qpwgraph
    qownnotes
    vlc
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
