{ pkgs, lib, ... }:
let
  remotionChromeLibs = with pkgs; [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libglvnd
    libnotify
    libuuid
    mesa
    nspr
    nss
    pango
    wayland
    zlib
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb
    xorg.libxshmfence
  ];
  nixLdPath = "${pkgs.nix-ld}/bin/nix-ld";
in
{
  # Ship nix-ld + libs to the user profile so Remotion's Chromium can link.
  home.packages = with pkgs; [
    nix-ld
  ];

  home.sessionVariables = {
    NIX_LD = nixLdPath;
    NIX_LD_LIBRARY_PATH = lib.makeLibraryPath remotionChromeLibs;
  };
}
