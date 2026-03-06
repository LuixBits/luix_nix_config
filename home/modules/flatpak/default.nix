{ pkgs, ... }:
let
  flatpakBin = "${pkgs.flatpak}/bin/flatpak";
  rsiScOutputGuard = pkgs.writeShellScriptBin "rsi-sc-output-guard" ''
    set -euo pipefail

    NIRI="${pkgs.niri}/bin/niri"
    JQ="${pkgs.jq}/bin/jq"
    MAIN_OUTPUT="HDMI-A-2"
    SIDE_OUTPUT="HDMI-A-3"
    HOLD_SECONDS=15
    LOG_FILE="/tmp/rsi-sc-output-guard.log"
    log() { printf '%s %s\n' "$(date -Iseconds)" "$*" >> "$LOG_FILE"; }

    log "start guard (main=$MAIN_OUTPUT side=$SIDE_OUTPUT)"

    outputs_json="$("$NIRI" msg -j outputs 2>/dev/null || true)"
    if [ -z "$outputs_json" ]; then
      log "niri outputs unavailable; exiting"
      exit 0
    fi

    if ! printf '%s\n' "$outputs_json" | "$JQ" -e --arg o "$MAIN_OUTPUT" 'has($o)' >/dev/null 2>&1; then
      log "main output $MAIN_OUTPUT not found; exiting"
      exit 0
    fi
    if ! printf '%s\n' "$outputs_json" | "$JQ" -e --arg o "$SIDE_OUTPUT" 'has($o)' >/dev/null 2>&1; then
      log "side output $SIDE_OUTPUT not found; exiting"
      exit 0
    fi

    side_off=0
    restore_side_output() {
      if [ "$side_off" -eq 1 ]; then
        log "restoring side output $SIDE_OUTPUT"
        "$NIRI" msg output "$SIDE_OUTPUT" on >/dev/null 2>&1 || true
        side_off=0
      fi
    }
    trap restore_side_output EXIT INT TERM

    "$NIRI" msg output "$SIDE_OUTPUT" off >/dev/null 2>&1 || true
    "$NIRI" msg action focus-monitor "$MAIN_OUTPUT" >/dev/null 2>&1 || true
    log "disabled $SIDE_OUTPUT and focused $MAIN_OUTPUT"
    side_off=1

    no_launcher_ticks=0
    for _ in $(seq 1 1200); do
      windows_json="$("$NIRI" msg -j windows 2>/dev/null || true)"
      if [ -z "$windows_json" ]; then
        sleep 0.5
        continue
      fi

      has_launcher="$(
        printf '%s\n' "$windows_json" | "$JQ" -r 'any(.[]; (.app_id // "") == "rsi launcher.exe")' 2>/dev/null || echo false
      )"
      has_game="$(
        printf '%s\n' "$windows_json" | "$JQ" -r 'any(.[]; (.app_id // "") == "starcitizen.exe")' 2>/dev/null || echo false
      )"

      if [ "$has_game" = "true" ]; then
        log "detected starcitizen.exe; holding $HOLD_SECONDS s before restore"
        sleep "$HOLD_SECONDS"
        log "hold done; exiting"
        exit 0
      fi

      if [ "$has_launcher" = "true" ]; then
        no_launcher_ticks=0
      else
        no_launcher_ticks=$((no_launcher_ticks + 1))
      fi

      if [ "$no_launcher_ticks" -ge 20 ]; then
        log "launcher gone before game start; exiting"
        exit 0
      fi

      sleep 0.5
    done
  '';
  rsiLauncher = pkgs.writeShellScriptBin "rsi-launcher" ''
    set -euo pipefail

    app_id="io.github.mactan_sc.RSILauncher"
    title="RSI Launcher"
    log_file="/tmp/rsi-launcher-wrapper.log"
    log() { printf '%s %s\n' "$(date -Iseconds)" "$*" >> "$log_file"; }
    log "wrapper invoked"

    find_win_id() {
      # xwininfo lists both mapped and unmapped windows, which is what we want here.
      xwininfo -root -tree 2>/dev/null | awk -v t="\"$title\"" '$0 ~ t { print $1; exit }'
    }

    if id="$(find_win_id)"; [ -n "''${id:-}" ]; then
      "${rsiScOutputGuard}/bin/rsi-sc-output-guard" >/tmp/rsi-sc-output-guard.log 2>&1 &
      wmctrl -ia "$id" || true
      log "existing launcher window found; started guard and focused"
      exit 0
    fi

    "${rsiScOutputGuard}/bin/rsi-sc-output-guard" >/tmp/rsi-sc-output-guard.log 2>&1 &
    log "started output guard"
    flatpak run "$app_id" >/tmp/rsilauncher-flatpak.log 2>&1 &
    log "started flatpak run"

    for _ in $(seq 1 60); do
      id="$(find_win_id || true)"
      if [ -n "''${id:-}" ]; then
        wmctrl -ia "$id" || true
        log "launcher window appeared; focused"
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
  # Tools used by the RSI launcher workaround
  home.packages = [
    # Needed to un-minimize/focus the RSI Launcher window under Xwayland.
    pkgs.wmctrl
    pkgs.xwininfo
    rsiLauncher
    rsiScOutputGuard
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
