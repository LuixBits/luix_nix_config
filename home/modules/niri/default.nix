{ config, pkgs, lib, hostName ? null, ... }:
let
  isWorkProfile = hostName == "work" || (hostName == null && config.home.username == "luiz");
  isLaptopProfile = hostName == "l";
  isPcProfile = hostName == "pc";
  workLaptopOutput = "eDP-1";
  # Match external displays by make/model/serial so DisplayLink connector order
  # changes do not break rotation/placement.
  workMainOutput = "PNP(BNQ) BenQ EX3415R R7M0014701Q";
  workRightPortraitOutput = "LG Electronics LG HDR 4K 405NTQDBG628";
  starCitizenMainOutput =
    if isLaptopProfile then
      workLaptopOutput
    else if isWorkProfile then
      workMainOutput
    else
      "HDMI-A-2";
  outputConfig =
    if isLaptopProfile then
      ''
        output "eDP-1" {
            mode "2880x1800@120.000"
            scale 1.75
            position x=0 y=0
            focus-at-startup
        }
      ''
    else if isWorkProfile then
      ''
        output "${workLaptopOutput}" {
            mode "2400x1600@60.000"
            scale 1.5
            position x=-1600 y=0
        }

        output "${workMainOutput}" {
            mode "3440x1440@59.973"
            position x=0 y=0
            focus-at-startup
        }

        output "${workRightPortraitOutput}" {
            mode "3840x2160@59.997"
            scale 1.25
            transform "270"
            position x=3440 y=0
        }
      ''
    else if isPcProfile then
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
  workRenderConfig =
    if isWorkProfile then
      ''
        // Keep work on the Intel render node: this is the only path that
        // consistently brings both DisplayLink outputs up.
        debug {
            render-drm-device "/dev/dri/by-path/pci-0000:00:02.0-render"
        }
      ''
    else
      "";
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
  kittyTerminalConfig = lib.replaceStrings [
    "    Mod+T hotkey-overlay-title=\"Open a Terminal: alacritty\" { spawn \"alacritty\"; }\n"
  ] [
    "    Mod+T hotkey-overlay-title=\"Open a Terminal: kitty\" { spawn \"kitty\"; }\n"
  ] noctaliaConfig;
  noBrightnessConfig = lib.replaceStrings [
    "    XF86MonBrightnessUp allow-when-locked=true { spawn \"brightnessctl\" \"--class=backlight\" \"set\" \"+10%\"; }\n"
    "    XF86MonBrightnessDown allow-when-locked=true { spawn \"brightnessctl\" \"--class=backlight\" \"set\" \"10%-\"; }\n"
  ] [
    ""
    ""
  ] kittyTerminalConfig;
  enforceStarCitizenOutput = pkgs.writeShellScript "niri-enforce-starcitizen-output" ''
    #!${pkgs.bash}/bin/bash
    set -u

    NIRI="${pkgs.niri}/bin/niri"
    JQ="${pkgs.jq}/bin/jq"
    TARGET_OUTPUT="${starCitizenMainOutput}"

    while true; do
      windows_json="$("$NIRI" msg -j windows 2>/dev/null || true)"
      workspaces_json="$("$NIRI" msg -j workspaces 2>/dev/null || true)"

      if [ -n "$windows_json" ] && [ -n "$workspaces_json" ]; then
        while IFS= read -r win_id; do
          [ -n "$win_id" ] || continue

          "$NIRI" msg action move-window-to-monitor "$TARGET_OUTPUT" --id "$win_id" >/dev/null 2>&1 || true
          "$NIRI" msg action maximize-window-to-edges --id "$win_id" >/dev/null 2>&1 || true
        done < <(
          printf '%s\n' "$windows_json" | "$JQ" -r \
            --argjson workspaces "$workspaces_json" \
            --arg target "$TARGET_OUTPUT" '
              [ $workspaces[] | { key: (.id | tostring), value: .output } ] | from_entries as $ws_output
              | .[]
              | select(.app_id == "starcitizen.exe")
              | select((.workspace_id | tostring) as $wsid | ($ws_output[$wsid] // "") != $target)
              | .id
            ' 2>/dev/null
        )
      fi

      sleep 1
    done
  '';
in
{
  imports = [
    ./noctalia
    ./polkit
  ];

  systemd.user.services.niri-starcitizen-output-fix = {
    Unit = {
      Description = "Keep Star Citizen on the main niri output";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${enforceStarCitizenOutput}";
      Restart = "always";
      RestartSec = 2;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  xdg.configFile."niri/config.kdl".text =
    noBrightnessConfig
    + ''
      ${outputConfig}
      ${workRenderConfig}

      // Star Citizen / RSI Launcher (Flatpak -> Proton/Wine) runs under Xwayland.
      // On mixed-DPI outputs, the game can request an oversized floating geometry
      // (e.g. 2160x3840 on a 1728x3072 logical output), which lands out of bounds.
      // Force known launcher/game app-ids onto the main output, in tiling layout,
      // and open maximized to edges.
      window-rule {
          match app-id=r#"^rsi launcher\.exe$"#
          match app-id=r#"^starcitizen\.exe$"#
          match app-id=r#"^steam_app_starcitizen$"#
          open-on-output "${starCitizenMainOutput}"
          open-floating false
          open-maximized-to-edges true
          open-focused true
      }
    '';
}
