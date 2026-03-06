{ pkgs, ... }:
let
  starCitizenMainOutput = "HDMI-A-2";
  starCitizenMainMode = "3440x1440@100.000";
  starCitizenFallbackMode = "3440x1440@59.973";
  flatpakBin = "${pkgs.flatpak}/bin/flatpak";
  launchRsiLauncher = pkgs.writeShellScript "launch-rsi-launcher" ''
    set -euo pipefail
    APP_ID="io.github.mactan_sc.RSILauncher"
    PREFIX_PATH="$HOME/.var/app/$APP_ID/data/prefix"
    TARGET_OUTPUT="${starCitizenMainOutput}"
    TARGET_MODE="${starCitizenMainMode}"
    TARGET_MODE_FALLBACK="${starCitizenFallbackMode}"
    TARGET_WIDTH="3440"
    TARGET_HEIGHT="1440"
    TARGET_WINDOW_MODE="2"
    WINE_DESKTOP_NAME="SC3440"
    last_sc_window_id=""

    strip_reg_section() {
      local reg_file="$1"
      local section="$2"
      local tmp_file
      tmp_file="$(mktemp)"
      awk -v section="$section" '
        BEGIN { skip = 0 }
        /^\[/ { skip = ($0 == section) }
        !skip { print }
      ' "$reg_file" >"$tmp_file"
      mv "$tmp_file" "$reg_file"
    }

    set_or_append_cfg() {
      local file="$1"
      local regex="$2"
      local replacement="$3"
      if [ ! -f "$file" ]; then
        return 0
      fi
      if grep -Eq "$regex" "$file"; then
        sed -i -E "s/$regex.*/$replacement/" "$file"
      else
        printf '\n%s\n' "$replacement" >>"$file"
      fi
    }

    force_star_citizen_settings() {
      local reg_file="$PREFIX_PATH/user.reg"
      local sc_root="$PREFIX_PATH/drive_c/Program Files/Roberts Space Industries/StarCitizen"
      local cfg_file
      local attr_file="$sc_root/LIVE/user/client/0/Profiles/default/attributes.xml"

      if [ -f "$reg_file" ]; then
        strip_reg_section "$reg_file" "[Software\\\\Wine\\\\Explorer\\\\Desktops]"
        strip_reg_section "$reg_file" "[Software\\\\Wine\\\\AppDefaults\\\\starcitizen.exe\\\\Explorer]"
        strip_reg_section "$reg_file" "[Software\\\\Wine\\\\AppDefaults\\\\StarCitizen.exe\\\\Explorer]"
        {
          echo ""
          echo "[Software\\\\Wine\\\\Explorer\\\\Desktops]"
          echo "\"$WINE_DESKTOP_NAME\"=\"''${TARGET_WIDTH}x''${TARGET_HEIGHT}\""
          echo ""
          echo "[Software\\\\Wine\\\\AppDefaults\\\\starcitizen.exe\\\\Explorer]"
          echo "\"Desktop\"=\"$WINE_DESKTOP_NAME\""
          echo ""
          echo "[Software\\\\Wine\\\\AppDefaults\\\\StarCitizen.exe\\\\Explorer]"
          echo "\"Desktop\"=\"$WINE_DESKTOP_NAME\""
        } >>"$reg_file"
      fi

      for cfg_file in "$sc_root/USER.cfg" "$sc_root/LIVE/USER.cfg"; do
        set_or_append_cfg "$cfg_file" '^r_width[[:space:]]*=' "r_width = $TARGET_WIDTH"
        set_or_append_cfg "$cfg_file" '^r_height[[:space:]]*=' "r_height = $TARGET_HEIGHT"
        set_or_append_cfg "$cfg_file" '^r_WindowMode[[:space:]]*=' "r_WindowMode = $TARGET_WINDOW_MODE"
      done

      if [ -f "$attr_file" ]; then
        sed -i -E 's/(<Attr name="Width" value=")[0-9]+(".*)/\1'"$TARGET_WIDTH"'\2/' "$attr_file"
        sed -i -E 's/(<Attr name="Height" value=")[0-9]+(".*)/\1'"$TARGET_HEIGHT"'\2/' "$attr_file"
        sed -i -E 's/(<Attr name="WindowMode" value=")[0-9]+(".*)/\1'"$TARGET_WINDOW_MODE"'\2/' "$attr_file"
      fi
    }

    # Force BenQ mode + SC resolution settings before launching.
    if command -v niri >/dev/null 2>&1; then
      if ! niri msg outputs 2>/dev/null | grep -Fq "($TARGET_OUTPUT)"; then
        echo "SC launch blocked: required output $TARGET_OUTPUT is not present." >&2
        exit 1
      fi
      niri msg output "$TARGET_OUTPUT" on >/dev/null 2>&1 || true
      niri msg output "$TARGET_OUTPUT" mode "$TARGET_MODE" >/dev/null 2>&1 \
        || niri msg output "$TARGET_OUTPUT" mode "$TARGET_MODE_FALLBACK" >/dev/null 2>&1 \
        || true
      niri msg action focus-monitor "$TARGET_OUTPUT" >/dev/null 2>&1 || true
    fi
    force_star_citizen_settings

    "${flatpakBin}" run "$APP_ID" &
    flatpak_pid="$!"

    while kill -0 "$flatpak_pid" 2>/dev/null; do
      if command -v niri >/dev/null 2>&1; then
        sc_window_id="$(
          niri msg windows 2>/dev/null | awk '
            /^Window ID / {
              id = $3
              sub(":", "", id)
            }
            /App ID: / {
              if ($0 ~ /"starcitizen\.exe"/ || $0 ~ /"steam_app_starcitizen"/) {
                print id
                exit
              }
            }
          '
        )"

        if [ -n "$sc_window_id" ]; then
          niri msg action move-window-to-monitor "$TARGET_OUTPUT" --id "$sc_window_id" >/dev/null 2>&1 || true
          if [ "$sc_window_id" != "$last_sc_window_id" ]; then
            niri msg action focus-window --id "$sc_window_id" >/dev/null 2>&1 || true
            niri msg action fullscreen-window --id "$sc_window_id" >/dev/null 2>&1 || true
            last_sc_window_id="$sc_window_id"
          fi
        fi
      fi

      sleep 1
    done

    wait "$flatpak_pid"
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

    # Use the launcher wrapper to enforce SC monitor/resolution behavior.
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
