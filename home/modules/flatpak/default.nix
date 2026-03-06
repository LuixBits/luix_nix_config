{ pkgs, ... }:
let
  flatpakBin = "${pkgs.flatpak}/bin/flatpak";
  rsiLauncher = pkgs.writeShellScriptBin "rsi-launcher" ''
    set -euo pipefail

    FLATPAK="${flatpakBin}"
    GAMESCOPE="${pkgs.gamescope}/bin/gamescope"
    NIRI="${pkgs.niri}/bin/niri"
    JQ="${pkgs.jq}/bin/jq"
    app_id="io.github.mactan_sc.RSILauncher"
    main_output="HDMI-A-2"
    game_width="3440"
    game_height="1440"
    log_file="/tmp/rsi-launcher-wrapper.log"
    log() { printf '%s %s\n' "$(date -Iseconds)" "$*" >> "$log_file"; }
    log "wrapper invoked (gamescope path)"

    windows_json="$("$NIRI" msg -j windows 2>/dev/null || true)"
    if [ -n "$windows_json" ]; then
      existing_id="$(
        printf '%s\n' "$windows_json" \
          | "$JQ" -r '.[] | select(((.app_id // "") == "rsi launcher.exe") or ((.app_id // "") == "starcitizen.exe") or ((.app_id // "") == "steam_app_starcitizen")) | .id' \
          | head -n1
      )"
      if [ -n "''${existing_id:-}" ]; then
        "$NIRI" msg action focus-window --id "$existing_id" >/dev/null 2>&1 || true
        log "focused existing RSI/SC window id=$existing_id"
        exit 0
      fi
    fi

    "$NIRI" msg action focus-monitor "$main_output" >/dev/null 2>&1 || true
    log "focused monitor $main_output and launching RSI under gamescope"

    # New approach: keep RSI/SC inside a single gamescope output on the main monitor.
    exec "$GAMESCOPE" -f -W "$game_width" -H "$game_height" -- "$FLATPAK" run "$app_id" \
      >/tmp/rsilauncher-flatpak.log 2>&1
  '';
  ensureRsiLauncher = pkgs.writeShellScript "ensure-rsi-launcher" ''
    set -euo pipefail
    FLATPAK="${flatpakBin}"
    APP_ID="io.github.mactan_sc.RSILauncher"
    PREFIX_PATH="$HOME/.var/app/$APP_ID/data/prefix"
    DESKTOP_DIR="$HOME/.local/share/applications"
    DESKTOP_FILE="$DESKTOP_DIR/$APP_ID.desktop"

    "$FLATPAK" remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    "$FLATPAK" remote-add --user --if-not-exists RSILauncher https://mactan-sc.github.io/rsilauncher/RSILauncher.flatpakrepo

    # RSI Launcher runs the Windows launcher under Proton/Wine and needs Flatpak's 32-bit compat + GL32 runtime.
    "$FLATPAK" install -y --user --noninteractive flathub \
      org.freedesktop.Platform.Compat.i386//24.08 \
      org.freedesktop.Platform.GL32.default//24.08

    "$FLATPAK" install -y --user --noninteractive RSILauncher "$APP_ID"

    # Keep permissions minimal and explicit: remove broad host access and expose only
    # the launcher prefix path used by Wine.
    "$FLATPAK" override --user --nofilesystem=host "$APP_ID"
    "$FLATPAK" override --user \
      --filesystem="$PREFIX_PATH" \
      --env=WINEPREFIX="$PREFIX_PATH" \
      "$APP_ID"

    # Flatpak may re-export its own desktop symlink in ~/.local/share/applications.
    # Force a local override that launches our host-side wrapper.
    mkdir -p "$DESKTOP_DIR"
    rm -f "$DESKTOP_FILE"
    cat >"$DESKTOP_FILE" <<'EOF'
[Desktop Entry]
Type=Application
Name=RSI Launcher
Comment=RSI Launcher
Exec=rsi-launcher
Icon=io.github.mactan_sc.RSILauncher
Terminal=false
Categories=Game;
StartupNotify=true
X-Flatpak=io.github.mactan_sc.RSILauncher
EOF
  '';
in
{
  # Tools used by the RSI launcher wrapper
  home.packages = [
    pkgs.gamescope
    rsiLauncher
  ];

  # Ensure remotes and RSI Launcher are present on each activation/login (idempotent)
  systemd.user.services.flatpak-rsi-launcher = {
    Unit = {
      Description = "Ensure RSI Launcher flatpak is installed";
      After = [ "graphical-session.target" "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = [ ensureRsiLauncher ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
