{ config, pkgs, ... }:

let
  # Vaporwave-styled KDE color scheme shared with Kdenlive.
  vaporwaveTheme = ./assets/vaporwave-dark.colors;
  vaporwaveThemeTarget = "${config.xdg.dataHome}/color-schemes/vaporwave-dark.colors";
  kdenliveWrapped = pkgs.symlinkJoin {
    name = "kdenlive-wrapped";
    paths = [ pkgs.kdePackages.kdenlive ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      # Torch from the Kdenlive venv expects libstdc++ in the runtime path.
      wrapProgram $out/bin/kdenlive \
        --prefix LD_LIBRARY_PATH : ${pkgs.stdenv.cc.cc.lib}/lib
    '';
  };
in {
  home.packages = [ kdenliveWrapped ];

  # Install the custom theme into the KDE color-schemes directory.
  home.file."${vaporwaveThemeTarget}".source = vaporwaveTheme;
}
