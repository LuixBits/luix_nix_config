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
    # Use the Proton/UMU runner path instead of plain Wine for launcher startup.
    umu.enable = true;
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
