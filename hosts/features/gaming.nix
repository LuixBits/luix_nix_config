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
    # Prefer native Wayland behavior for Wine on Niri.
    enforceWaylandDrv = true;
    gamescope = {
      enable = true;
      args = [ "-f" ];
    };
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
