{ pkgs, ... }:
let
  flatpakBin = "${pkgs.flatpak}/bin/flatpak";
  gamescopeBin = "${pkgs.gamescope}/bin/gamescope";

  rsiLauncher = pkgs.writeShellScriptBin "rsi-launcher" ''
    exec ${flatpakBin} run io.github.mactan_sc.RSILauncher
  '';

  rsiLauncherFullscreen = pkgs.writeShellScriptBin "rsi-launcher-fs" ''
    set -euo pipefail

    OUTPUT="''${RSI_OUTPUT:-HDMI-A-2}"
    WIDTH="''${RSI_WIDTH:-3440}"
    HEIGHT="''${RSI_HEIGHT:-1440}"
    REFRESH="''${RSI_REFRESH:-100}"
    INTERNAL_WIDTH="''${RSI_INTERNAL_WIDTH:-$WIDTH}"
    INTERNAL_HEIGHT="''${RSI_INTERNAL_HEIGHT:-$HEIGHT}"

    args=(
      -f
      -W "$WIDTH"
      -H "$HEIGHT"
      -w "$INTERNAL_WIDTH"
      -h "$INTERNAL_HEIGHT"
      -r "$REFRESH"
    )

    if [[ -n "$OUTPUT" ]]; then
      args+=(-O "$OUTPUT")
    fi

    exec ${gamescopeBin} "''${args[@]}" -- ${flatpakBin} run io.github.mactan_sc.RSILauncher
  '';
in
{
  home.packages = [
    rsiLauncher
    rsiLauncherFullscreen
  ];
}
