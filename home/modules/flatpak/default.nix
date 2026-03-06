{ pkgs, ... }:
let
  flatpakBin = "${pkgs.flatpak}/bin/flatpak";
  rsiLauncher = pkgs.writeShellScriptBin "rsi-launcher" ''
    set -euo pipefail

    FLATPAK="${flatpakBin}"
    XWAYLAND_RUN="${pkgs.xwayland-run}/bin/xwayland-run"
    APP_ID="io.github.mactan_sc.RSILauncher"
    TARGET_OUTPUT="HDMI-A-2"
    TARGET_OUTPUT_MODEL="BenQ EX3415R"
    TARGET_GEOMETRY="3440x1440"

    if command -v niri >/dev/null 2>&1; then
      detected_output="$(
        niri msg outputs 2>/dev/null | awk -v model="$TARGET_OUTPUT_MODEL" '
          /^Output / && index($0, model) {
            if (match($0, /\(([^)]+)\)/, m)) {
              print m[1]
              exit
            }
          }
        '
      )"
      if [ -n "''${detected_output:-}" ]; then
        TARGET_OUTPUT="$detected_output"
      fi
    fi

    # Avoid duplicate container instances.
    if "$FLATPAK" ps --columns=application 2>/dev/null | grep -Fx "$APP_ID" >/dev/null; then
      exit 0
    fi

    # Force RSI + SC into a dedicated rootful Xwayland pinned to BenQ.
    # This prevents monitor hopping during EAC/SC window recreation.
    exec "$XWAYLAND_RUN" \
      -fullscreen \
      -output "$TARGET_OUTPUT" \
      -geometry "$TARGET_GEOMETRY" \
      -- "$FLATPAK" run --nosocket=wayland --socket=fallback-x11 "$APP_ID" \
      >/tmp/rsilauncher-flatpak.log 2>&1
  '';
  ensureRsiLauncher = pkgs.writeShellScript "ensure-rsi-launcher" ''
    set -euo pipefail
    FLATPAK="${flatpakBin}"
    APP_ID="io.github.mactan_sc.RSILauncher"
    PREFIX_PATH="$HOME/.var/app/$APP_ID/data/prefix"
    DESKTOP_DIR="$HOME/.local/share/applications"
    DESKTOP_FILE="$DESKTOP_DIR/$APP_ID.desktop"
    USER_REG="$PREFIX_PATH/user.reg"

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

    # Remove stale Wine virtual-desktop overrides from old SC experiments.
    # They can persist in the prefix and cause Star Citizen to fail creating
    # its first game window.
    if [ -f "$USER_REG" ]; then
      tmp_reg="$(mktemp)"
      awk '
        BEGIN { skip = 0 }
        /^\[/ {
          if ($0 ~ /^\[Software\\\\Wine\\\\Explorer\\\\Desktops\]/) {
            skip = 1
          } else if ($0 ~ /^\[Software\\\\Wine\\\\AppDefaults\\\\[Ss]tarcitizen\.exe\\\\Explorer\]/) {
            skip = 1
          } else {
            skip = 0
          }
        }
        !skip { print }
      ' "$USER_REG" >"$tmp_reg"
      mv "$tmp_reg" "$USER_REG"
    fi

    # Force a local desktop entry that calls our wrapper. This also replaces
    # stale manual overrides from previous troubleshooting.
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
  # Tools used by the RSI launcher workaround
  home.packages = [
    rsiLauncher
  ];

  # Workaround: RSI Launcher (Electron via Proton/Wine) sometimes starts minimized on Niri/Xwayland.
  # Provide a user desktop entry with the same id as the Flatpak export to override it cleanly.
  xdg.desktopEntries."io.github.mactan_sc.RSILauncher" = {
    name = "RSI Launcher";
    exec = "rsi-launcher";
    icon = "io.github.mactan_sc.RSILauncher";
    terminal = false;
    categories = [ "Game" ];
  };

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
