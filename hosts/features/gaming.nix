{ inputs, pkgs, ... }:
{
  imports = [
    inputs.nix-citizen.nixosModules.default
  ];

  programs.steam.enable = true; # enables Steam and required 32-bit runtime
  programs.gamemode.enable = true;
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.rsi-launcher = {
    enable = true;
    # Helps with common pointer issues on Wayland compositors.
    patchXwayland = true;
    # More stable pointer coordinates on Niri than forcing Wine Wayland.
    enforceWaylandDrv = false;
    gamescope = {
      # The launcher itself does not present reliably on this setup without
      # running inside gamescope.
      enable = true;
      args = [
        "-W"
        "3440"
        "-H"
        "1440"
        "--force-grab-cursor"
      ];
    };
    preCommands = ''
      # SC cursor mapping is unreliable with the secondary LG output active on
      # this Niri setup. Turn it off for the session and restore it on exit.
      niri_bin='${pkgs.niri}/bin/niri'
      if [ -x "$niri_bin" ]; then
        sc_aux_output="LG Electronics LG HDR 4K 405NTQDBG628"
        if "$niri_bin" msg outputs 2>/dev/null | grep -Fq "Output \"$sc_aux_output\""; then
          export SC_REENABLE_OUTPUT="$sc_aux_output"
          "$niri_bin" msg output "$sc_aux_output" off || true
          sleep 2
        fi
      fi

      # Hint Wine Wayland to use the BenQ ultrawide as primary.
      # Connector IDs can shift when displays are toggled, so detect by mode.
      for status_file in /sys/class/drm/card*-*/status; do
        [ -r "$status_file" ] || continue
        [ "$(cat "$status_file")" = "connected" ] || continue

        conn_dir="''${status_file%/status}"
        if grep -q '^3440x1440' "$conn_dir/modes" 2>/dev/null; then
          monitor="''${conn_dir##*/}"
          export WAYLANDDRV_PRIMARY_MONITOR="''${monitor#*-}"
          break
        fi
      done

      # Keep SC USER.cfg aligned with ultrawide resolution and cursor workaround.
      for channel in LIVE PTU; do
        cfg_dir="$WINEPREFIX/drive_c/Program Files/Roberts Space Industries/StarCitizen/$channel"
        mkdir -p "$cfg_dir"
        cat > "$cfg_dir/USER.cfg" <<'EOF'
r_width = 3440
r_height = 1440
pl_pit.forceSoftwareCursor = 1
EOF
      done
    '';
    postCommands = ''
      niri_bin='${pkgs.niri}/bin/niri'
      if [ -n "''${SC_REENABLE_OUTPUT:-}" ] && [ -x "$niri_bin" ]; then
        "$niri_bin" msg output "$SC_REENABLE_OUTPUT" on || true
      fi
    '';
  };

  hardware.graphics.enable32Bit = true;

  nix.settings = {
    # Caches from nix-citizen + nix-gaming READMEs
    substituters = [
      "https://nix-citizen.cachix.org"
      "https://nix-gaming.cachix.org"
    ];
    trusted-public-keys = [
      "nix-citizen.cachix.org-1:lPMkWc2X8XD4/7YPEEwXKKBg+SVbYTVrAaLA2wQTKCo="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    ];
  };
}
