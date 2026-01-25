{ pkgs, ... }:
let
  mainOutputName = "DP-1";
  verticalOutputName = "HDMI-A-1";
in
{
  programs.fuzzel.enable = true;

  xdg.configFile."niri/config.kdl".text = ''
    include "${pkgs.niri.doc}/share/doc/niri/default-config.kdl"

    output "${mainOutputName}" {
        mode "3440x1440@100.000"
        position x=0 y=0
        focus-at-startup
    }

    output "${verticalOutputName}" {
        mode "3440x1440@60.000"
        transform "90"
        position x=3440 y=720
    }
  '';
}
