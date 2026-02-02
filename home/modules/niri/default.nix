{ pkgs, lib, ... }:
let
  mainOutputName = "HDMI-A-2";
  verticalOutputName = "HDMI-A-3";
  baseConfig = builtins.readFile "${pkgs.niri.doc}/share/doc/niri/default-config.kdl";
  noWaybarConfig = lib.replaceStrings [
    "spawn-at-startup \"waybar\"\n"
  ] [
    ""
  ] baseConfig;
  noCommaConfig = lib.replaceStrings [
    "    Mod+Comma  { consume-window-into-column; }\n"
  ] [
    ""
  ] noWaybarConfig;
  widthConfig = lib.replaceStrings [
    "    Mod+Period { expel-window-from-column; }\n"
  ] [
    "    Mod+Period { set-column-width \"+10%\"; }\n"
  ] noCommaConfig;
  noctaliaLauncherBinds = ''
    Mod+Space hotkey-overlay-title="Noctalia: Launcher" { spawn "noctalia-shell" "ipc" "call" "launcher" "toggle"; }
    Mod+D hotkey-overlay-title="Noctalia: Launcher" { spawn "noctalia-shell" "ipc" "call" "launcher" "toggle"; }
    Mod+S hotkey-overlay-title="Noctalia: Control Center" { spawn "noctalia-shell" "ipc" "call" "controlCenter" "toggle"; }
    Mod+Comma hotkey-overlay-title="Noctalia: Settings" { spawn "noctalia-shell" "ipc" "call" "settings" "toggle"; }
  '';
  noctaliaLockBind = ''
    Super+Alt+L hotkey-overlay-title="Noctalia: Lock" { spawn "noctalia-shell" "ipc" "call" "lockScreen" "lock"; }
  '';
  noFuzzelConfig = lib.replaceStrings [
    "    Mod+D hotkey-overlay-title=\"Run an Application: fuzzel\" { spawn \"fuzzel\"; }\n"
  ] [
    "    ${noctaliaLauncherBinds}\n"
  ] widthConfig;
  noctaliaConfig = lib.replaceStrings [
    "    Super+Alt+L hotkey-overlay-title=\"Lock the Screen: swaylock\" { spawn \"swaylock\"; }\n"
  ] [
    "    ${noctaliaLockBind}\n"
  ] noFuzzelConfig;
in
{
  imports = [
    ./audio
    ./clipboard
    ./noctalia
    ./notifications
    ./screenshot
  ];

  xdg.configFile."niri/config.kdl".text =
    noctaliaConfig
    + ''

      output "${mainOutputName}" {
          mode "3440x1440@100.000"
          position x=0 y=0
          focus-at-startup
      }

      output "${verticalOutputName}" {
          mode "3840x2160@59.997"
          scale 1.25
          transform "270"
          position x=3440 y=0
      }
    '';
}
