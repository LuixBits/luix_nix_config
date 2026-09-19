{
  lib,
  machine ? null,
  pkgs,
  ...
}:
let
  isFrameworkMachine = machine == "framework";
  isLaptopProfile = machine == "l";
  isPcProfile = machine == "pc";
  laptopInternalOutput = "eDP-1";
  sharedMainOutput = "PNP(BNQ) BenQ EX3415R R7M0014701Q";
  sharedRightPortraitOutput = "LG Electronics LG HDR 4K 405NTQDBG628";
  # Match external displays by make/model/serial so DisplayLink connector order
  # changes do not break rotation/placement.
  pcMainOutput = sharedMainOutput;
  pcRightPortraitOutput = sharedRightPortraitOutput;
  outputConfig =
    if isLaptopProfile then
      ''
        output "${laptopInternalOutput}" {
            mode "2880x1800@120.000"
            scale 1.75
            position x=0 y=0
        }

        output "${sharedMainOutput}" {
            position x=1646 y=0
            focus-at-startup
        }

        output "${sharedRightPortraitOutput}" {
            scale 1.25
            transform "270"
            position x=5086 y=0
        }

        // The build-vm capture rig exposes the panel as Virtual-1. Real
        // hardware never has this output, so niri ignores the block there.
        output "Virtual-1" {
            scale 1.75
            position x=0 y=0
        }
      ''
    else if isFrameworkMachine then
      # Shikane owns the Framework panel and work-display layouts.
      ""
    else if isPcProfile then
      ''
        output "${pcMainOutput}" {
            mode "3440x1440@100.000"
            position x=0 y=0
            focus-at-startup
        }

        output "${pcRightPortraitOutput}" {
            mode "3840x2160@59.997"
            scale 1.25
            transform "270"
            position x=3440 y=0
        }
      ''
    else
      ''
        output "HDMI-A-2" {
            mode "3440x1440@100.000"
            position x=0 y=0
            focus-at-startup
        }

        output "HDMI-A-3" {
            mode "3840x2160@59.997"
            scale 1.25
            transform "270"
            position x=3440 y=0
        }
      '';
  baseConfig = builtins.readFile "${pkgs.niri.doc}/share/doc/niri/default-config.kdl";
  noWaybarConfig =
    lib.replaceStrings
      [
        "spawn-at-startup \"waybar\"\n"
      ]
      [
        ""
      ]
      baseConfig;
  noCommaConfig =
    lib.replaceStrings
      [
        "    Mod+Comma  { consume-window-into-column; }\n"
      ]
      [
        ""
      ]
      noWaybarConfig;
  widthConfig =
    lib.replaceStrings
      [
        "    Mod+Period { expel-window-from-column; }\n"
      ]
      [
        "    Mod+Period { set-column-width \"+10%\"; }\n"
      ]
      noCommaConfig;
  noctaliaLauncherBinds = ''
    Mod+Space hotkey-overlay-title="Noctalia: Launcher" { spawn "noctalia-ipc" "panel-toggle" "launcher"; }
    Mod+D hotkey-overlay-title="Noctalia: Launcher" { spawn "noctalia-ipc" "panel-toggle" "launcher"; }
    Mod+S hotkey-overlay-title="Noctalia: Control Center" { spawn "noctalia-ipc" "panel-toggle" "control-center"; }
    Mod+Comma hotkey-overlay-title="Noctalia: Settings" { spawn "noctalia-ipc" "settings-toggle"; }
  '';
  noctaliaLockBind = ''
    Super+Alt+L hotkey-overlay-title="Noctalia: Lock" { spawn "noctalia-ipc" "session" "lock"; }
  '';
  noFuzzelConfig =
    lib.replaceStrings
      [
        "    Mod+D hotkey-overlay-title=\"Run an Application: fuzzel\" { spawn \"fuzzel\"; }\n"
      ]
      [
        "    ${noctaliaLauncherBinds}\n"
      ]
      widthConfig;
  noctaliaConfig =
    lib.replaceStrings
      [
        "    Super+Alt+L hotkey-overlay-title=\"Lock the Screen: swaylock\" { spawn \"swaylock\"; }\n"
      ]
      [
        "    ${noctaliaLockBind}\n"
      ]
      noFuzzelConfig;
  kittyTerminalConfig =
    lib.replaceStrings
      [
        "    Mod+T hotkey-overlay-title=\"Open a Terminal: alacritty\" { spawn \"alacritty\"; }\n"
      ]
      [
        "    Mod+T hotkey-overlay-title=\"Open a Terminal: kitty\" { spawn \"kitty\"; }\n"
      ]
      noctaliaConfig;
  noBrightnessConfig =
    lib.replaceStrings
      [
        "    XF86MonBrightnessUp allow-when-locked=true { spawn \"brightnessctl\" \"--class=backlight\" \"set\" \"+10%\"; }\n"
        "    XF86MonBrightnessDown allow-when-locked=true { spawn \"brightnessctl\" \"--class=backlight\" \"set\" \"10%-\"; }\n"
      ]
      [
        ""
        ""
      ]
      kittyTerminalConfig;
in
{
  imports = [
    ./cursors.nix
    ./display-profiles.nix
    ./noctalia
    ./polkit
  ];

  xdg.configFile."niri/config.kdl".text = noBrightnessConfig + outputConfig;
}
