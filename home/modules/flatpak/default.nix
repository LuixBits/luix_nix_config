{ pkgs, ... }:
let
  flatpakBin = "${pkgs.flatpak}/bin/flatpak";
  pinnedProton = "GE-Proton10-29";
  rsiLauncher = pkgs.writeShellScriptBin "rsi-launcher" ''
    set -euo pipefail

    APP_ID="io.github.mactan_sc.RSILauncher"
    TITLE="RSI Launcher"
    PROTONPATH_PIN="${pinnedProton}"

    find_win_id() {
      # xwininfo lists both mapped and unmapped windows, which is what we want here.
      xwininfo -root -tree 2>/dev/null | awk -v t="\"$TITLE\"" '$0 ~ t { print $1; exit }'
    }

    if id="$(find_win_id)"; [ -n "''${id:-}" ]; then
      wmctrl -ia "$id" || true
      exit 0
    fi

    # Some shells/tooling export Electron Node-mode flags, which makes
    # the Windows RSI Electron app exit immediately.
    unset ELECTRON_RUN_AS_NODE || true
    unset ELECTRON_NO_ATTACH_CONSOLE || true

    # Keep launcher behavior simple and stable: run Flatpak directly with a known-good Proton.
    exec "${flatpakBin}" run \
      --env=PROTONPATH="$PROTONPATH_PIN" \
      "$APP_ID"
  '';

  ensureRsiLauncher = pkgs.writeShellScript "ensure-rsi-launcher" ''
    set -euo pipefail

    FLATPAK="${flatpakBin}"
    WRAPPER="${rsiLauncher}/bin/rsi-launcher"
    APP_ID="io.github.mactan_sc.RSILauncher"
    PREFIX_PATH="$HOME/.var/app/$APP_ID/data/prefix"
    DESKTOP_DIR="$HOME/.local/share/applications"
    DESKTOP_FILE="$DESKTOP_DIR/$APP_ID.desktop"
    FLATPAK_EXPORT_DIR="$HOME/.local/share/flatpak/exports/share/applications"
    FLATPAK_EXPORT_DESKTOP="$FLATPAK_EXPORT_DIR/$APP_ID.desktop"
    USER_REG="$PREFIX_PATH/user.reg"
    LAUNCHER_CFG="$HOME/.var/app/$APP_ID/config/starcitizen-lug/launcher.cfg"

    "$FLATPAK" remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    "$FLATPAK" remote-add --user --if-not-exists RSILauncher https://mactan-sc.github.io/rsilauncher/RSILauncher.flatpakrepo

    # RSI Launcher runs the Windows launcher under Proton/Wine and needs Flatpak's 32-bit compat + GL32 runtime.
    "$FLATPAK" install -y --user --noninteractive flathub \
      org.freedesktop.Platform.Compat.i386//24.08 \
      org.freedesktop.Platform.GL32.default//24.08

    "$FLATPAK" install -y --user --noninteractive RSILauncher "$APP_ID"

    # Reset any stale troubleshooting overrides, then apply only the minimal required set.
    "$FLATPAK" override --user --reset "$APP_ID"
    "$FLATPAK" override --user --nofilesystem=host "$APP_ID"
    "$FLATPAK" override --user \
      --filesystem="$PREFIX_PATH" \
      --env=WINEPREFIX="$PREFIX_PATH" \
      --env=PROTONPATH="${pinnedProton}" \
      --unset-env=ELECTRON_RUN_AS_NODE \
      --unset-env=ELECTRON_NO_ATTACH_CONSOLE \
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

    # Keep launcher.cfg from re-enabling Proton Wayland unexpectedly.
    if [ -f "$LAUNCHER_CFG" ]; then
      sed -i 's/^PROTON_ENABLE_WAYLAND=1$/# PROTON_ENABLE_WAYLAND=1/' "$LAUNCHER_CFG"
    fi

    # Force a local desktop entry that calls our wrapper.
    mkdir -p "$DESKTOP_DIR"
    rm -f "$DESKTOP_FILE"
    cat >"$DESKTOP_FILE" <<EOF_DESKTOP
[Desktop Entry]
Type=Application
Name=RSI Launcher
Comment=RSI Launcher
Exec=$WRAPPER
Icon=io.github.mactan_sc.RSILauncher
Terminal=false
Categories=Game;
StartupNotify=true
X-Flatpak=io.github.mactan_sc.RSILauncher
EOF_DESKTOP

    # Some launchers index the Flatpak export path directly. Override that
    # desktop file too so every launcher path executes the same wrapper.
    mkdir -p "$FLATPAK_EXPORT_DIR"
    rm -f "$FLATPAK_EXPORT_DESKTOP"
    cat >"$FLATPAK_EXPORT_DESKTOP" <<EOF_EXPORT
[Desktop Entry]
Type=Application
Name=RSI Launcher
Comment=RSI Launcher
Exec=$WRAPPER
Icon=io.github.mactan_sc.RSILauncher
Terminal=false
Categories=Game;
StartupNotify=true
X-Flatpak=io.github.mactan_sc.RSILauncher
EOF_EXPORT
  '';
in
{
  # Tools used by the RSI launcher wrapper.
  home.packages = [
    pkgs.wmctrl
    pkgs.xwininfo
    rsiLauncher
  ];

  # Provide a user desktop entry with the same id as the Flatpak export.
  xdg.desktopEntries."io.github.mactan_sc.RSILauncher" = {
    name = "RSI Launcher";
    exec = "${rsiLauncher}/bin/rsi-launcher";
    icon = "io.github.mactan_sc.RSILauncher";
    terminal = false;
    categories = [ "Game" ];
  };

  # Ensure remotes and RSI Launcher are present on each activation/login (idempotent).
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
