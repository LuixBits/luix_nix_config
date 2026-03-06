{ pkgs, ... }:
let
  flatpakBin = "${pkgs.flatpak}/bin/flatpak";
  rsiLauncher = pkgs.writeShellScriptBin "rsi-launcher" ''
    set -euo pipefail

    FLATPAK="${flatpakBin}"
    XWAYLAND_RUN="${pkgs.xwayland-run}/bin/xwayland-run"
    APP_ID="io.github.mactan_sc.RSILauncher"
    GEOMETRY="3440x1440"

    # Avoid spawning duplicate launcher instances.
    if "$FLATPAK" ps --columns=application 2>/dev/null | grep -Fx "$APP_ID" >/dev/null; then
      exit 0
    fi

    # Run RSI/SC in a dedicated Xwayland server with a stable geometry.
    # This keeps Star Citizen startup deterministic and avoids transient
    # Wayland/Xwayland monitor handoff issues.
    exec "$XWAYLAND_RUN" -geometry "$GEOMETRY" -fullscreen -- \
      "$FLATPAK" run --nosocket=wayland --socket=fallback-x11 "$APP_ID" \
      >/tmp/rsilauncher-flatpak.log 2>&1
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
