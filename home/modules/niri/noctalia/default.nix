{ config, inputs, lib, pkgs, hostName ? null, ... }:
let
  sharedSettings = {
    shell = {
      avatar_path = "/home/luix/.face";
      settings_show_advanced = true;
    };

    wallpaper = {
      enabled = true;
      directory = "/home/luix/Pictures/Wallpapers";
    };

    desktop_widgets.enabled = false;
    lockscreen_widgets.enabled = false;
  };

  perHostSettings = {
    l = {
      dock.monitors = [ "eDP-1" ];
    };

    pc = {
      dock.monitors = [ "HDMI-A-2" ];
    };

    work = {
      shell.animation.enabled = false;
      shell.shadow.alpha = 0.0;
      dock.monitors = [ "DP-2" "DP-1" "eDP-1" ];
      backdrop.enabled = false;
    };
  };

  hostSettings =
    if hostName != null && builtins.hasAttr hostName perHostSettings then
      perHostSettings.${hostName}
    else
      { };

  noctaliaSettings = lib.recursiveUpdate sharedSettings hostSettings;

  noctaliaIpc = pkgs.writeShellScriptBin "noctalia-ipc" ''
    set -eu

    noctalia=${lib.escapeShellArg (lib.getExe config.programs.noctalia.package)}

    exec "$noctalia" msg "$@"
  '';
in
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia = {
    enable = true;
    settings = noctaliaSettings;
  };

  home.packages = [ noctaliaIpc ];
}
