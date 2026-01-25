{ pkgs, ... }:
let
  mainOutputName = "HDMI-A-2";
  verticalOutputName = "HDMI-A-3";
in
{
  imports = [
    ./mako
    ./waybar
  ];

  programs.fuzzel.enable = true;

  xdg.configFile."niri/config.kdl".text = ''
    include "${pkgs.niri.doc}/share/doc/niri/default-config.kdl"

    output "${mainOutputName}" {
        mode "3440x1440@100.000"
        position x=0 y=0
        focus-at-startup
    }

    output "${verticalOutputName}" {
        mode "3840x2160@59.997"
        scale 1.25
        transform "270"
        position x=3440 y=720
    }
  '';
}
