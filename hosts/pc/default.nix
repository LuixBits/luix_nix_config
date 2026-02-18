{ ... }:
{
  imports = [
    ../common/base.nix
    ../features/hardware-amd.nix
    ../features/peripheral-quirks.nix
    ../features/pc-mass-storage.nix
    ../features/media-tools.nix
    ../features/flatpak.nix
    ../features/gaming.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "pc";
}
