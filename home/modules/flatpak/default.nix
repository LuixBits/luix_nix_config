{ pkgs, ... }:
let
  starCitizenMainOutput = "HDMI-A-2";
  starCitizenResolution = "3440x1440";
  flatpakBin = "${pkgs.flatpak}/bin/flatpak";
  xwaylandRunBin = "${pkgs.xwayland-run}/bin/xwayland-run";
  launchRsiLauncher = pkgs.writeShellScript "launch-rsi-launcher" ''
    set -euo pipefail
    APP_ID="io.github.mactan_sc.RSILauncher"
    TARGET_OUTPUT="${starCitizenMainOutput}"
    GEOMETRY="${starCitizenResolution}"

    # Hard requirement: SC may only run on the BenQ output at 3440x1440.
    if command -v niri >/dev/null 2>&1; then
      if ! niri msg outputs 2>/dev/null | grep -Fq "($TARGET_OUTPUT)"; then
        echo "SC launch blocked: required output $TARGET_OUTPUT is not present." >&2
        exit 1
      fi
    fi

    exec "${xwaylandRunBin}" \
      -output "$TARGET_OUTPUT" \
      -geometry "$GEOMETRY" \
      -fullscreen \
      -- "${flatpakBin}" run "$APP_ID"
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

    # Use the xwayland-run wrapper desktop command to expose a single
    # fullscreen monitor to Wine and prevent SC monitor hopping.
    mkdir -p "$DESKTOP_DIR"
    rm -f "$DESKTOP_FILE"
    cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=RSI Launcher
Comment=RSI Launcher
Exec=${launchRsiLauncher}
Icon=io.github.mactan_sc.RSILauncher
Terminal=false
Categories=Game;
StartupNotify=true
X-Flatpak=io.github.mactan_sc.RSILauncher
EOF
  '';
in
{
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
