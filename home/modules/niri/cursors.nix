# Banana cursor shared by Home Manager and Niri.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.pointerCursor = {
    enable = true;
    package = pkgs.banana-cursor;
    name = "Banana";
    size = 32;
    gtk.enable = true;
    x11.enable = true;
  };

  gtk.enable = true;

  # This repository generates KDL directly; derive Niri's cursor from the
  # same Home Manager choice used for GTK, Xcursor defaults, and XWayland.
  xdg.configFile."niri/config.kdl".text = lib.mkAfter ''

    cursor {
        xcursor-theme "${config.home.pointerCursor.name}"
        xcursor-size ${toString config.home.pointerCursor.size}
    }
  '';
}
