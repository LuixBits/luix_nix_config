{ config, ... }:

let
  # Vaporwave-styled KDE color scheme shared with Kdenlive.
  vaporwaveTheme = ./assets/kdenlive/vaporwave-dark.colors;
  vaporwaveThemeTarget = "${config.xdg.dataHome}/color-schemes/vaporwave-dark.colors";
in {
  # Install the custom theme into the KDE color-schemes directory.
  home.file."${vaporwaveThemeTarget}".source = vaporwaveTheme;
}
