{ inputs, ... }:
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
