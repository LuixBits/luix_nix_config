{ pkgs, ... }:
let
  flatpakBin = "${pkgs.flatpak}/bin/flatpak";
  rsiLauncher = pkgs.writeShellScriptBin "rsi-launcher" ''
    set -euo pipefail

    app_id="io.github.mactan_sc.RSILauncher"
    title="RSI Launcher"

    find_win_id() {
      # xwininfo lists both mapped and unmapped windows, which is what we want here.
      xwininfo -root -tree 2>/dev/null | awk -v t="\"$title\"" '$0 ~ t { print $1; exit }'
    }

    if id="$(find_win_id)"; [ -n "''${id:-}" ]; then
      wmctrl -ia "$id" || true
      exit 0
    fi

    flatpak run "$app_id" >/tmp/rsilauncher-flatpak.log 2>&1 &

    for _ in $(seq 1 60); do
      id="$(find_win_id || true)"
      if [ -n "''${id:-}" ]; then
        wmctrl -ia "$id" || true
        exit 0
      fi
      sleep 0.25
    done

    echo "RSI Launcher started but no X11 window titled \"$title\" appeared. See /tmp/rsilauncher-flatpak.log" >&2
    exit 1
  '';
  ensureRsiLauncher = pkgs.writeShellScript "ensure-rsi-launcher" ''
    set -euo pipefail
    FLATPAK="${flatpakBin}"
    APP_ID="io.github.mactan_sc.RSILauncher"
    PREFIX_PATH="$HOME/.var/app/$APP_ID/data/prefix"

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
  '';
in
{
  # Tools used by the RSI launcher workaround
  home.packages = [
    # Needed to un-minimize/focus the RSI Launcher window under Xwayland.
    pkgs.wmctrl
    pkgs.xwininfo
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
