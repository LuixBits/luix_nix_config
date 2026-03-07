{ pkgs, ... }:
let
  flatpakBin = "${pkgs.flatpak}/bin/flatpak";
  appId = "io.github.mactan_sc.RSILauncher";
  pinnedProton = "GE-Proton10-29";
  ensureRsiLauncher = pkgs.writeShellScript "ensure-rsi-launcher" ''
    set -euo pipefail

    FLATPAK="${flatpakBin}"
    APP_ID="${appId}"
    PREFIX_PATH="$HOME/.var/app/$APP_ID/data/prefix"
    USER_REG="$PREFIX_PATH/user.reg"
    LAUNCHER_CFG="$HOME/.var/app/$APP_ID/config/starcitizen-lug/launcher.cfg"
    USER_DESKTOP="$HOME/.local/share/applications/$APP_ID.desktop"
    EXPORT_DESKTOP="$HOME/.local/share/flatpak/exports/share/applications/$APP_ID.desktop"
    EXPORT_BIN_WRAPPER="$HOME/.local/share/flatpak/exports/bin/rsi-launcher"

    "$FLATPAK" remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    "$FLATPAK" remote-add --user --if-not-exists RSILauncher https://mactan-sc.github.io/rsilauncher/RSILauncher.flatpakrepo

    "$FLATPAK" install -y --user --noninteractive flathub \
      org.freedesktop.Platform.Compat.i386//24.08 \
      org.freedesktop.Platform.GL32.default//24.08

    # Keep the app itself stock; do not route through custom wrapper binaries.
    "$FLATPAK" install -y --user --noninteractive --reinstall RSILauncher "$APP_ID"

    # Keep only runtime overrides needed for this prefix.
    "$FLATPAK" override --user --reset "$APP_ID"
    "$FLATPAK" override --user --nofilesystem=host "$APP_ID"
    "$FLATPAK" override --user \
      --filesystem="$PREFIX_PATH" \
      --env=WINEPREFIX="$PREFIX_PATH" \
      --env=PROTONPATH="${pinnedProton}" \
      --unset-env=ELECTRON_RUN_AS_NODE \
      --unset-env=ELECTRON_NO_ATTACH_CONSOLE \
      "$APP_ID"

    # Remove stale custom desktop/wrapper overrides from earlier troubleshooting.
    rm -f "$USER_DESKTOP"
    rm -f "$EXPORT_DESKTOP"
    rm -f "$EXPORT_BIN_WRAPPER"
    mkdir -p "$(dirname "$EXPORT_DESKTOP")"
    ln -sf "../../../app/$APP_ID/current/active/export/share/applications/$APP_ID.desktop" "$EXPORT_DESKTOP"

    # Remove stale Wine virtual-desktop overrides from old SC experiments.
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
  '';
in
{
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
