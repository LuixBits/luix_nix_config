{ ... }:
{
  imports = [
    ../common/base.nix
    ../features/hardware-amd.nix
    ../../audiofix.nix
    ../features/pc-mass-storage.nix
    ../features/media-tools.nix
    ../features/flatpak.nix
    ../features/gaming.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "pc";
}
