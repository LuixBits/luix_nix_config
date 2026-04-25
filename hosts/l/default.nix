{ ... }:
{
  imports = [
    ../common/base.nix
    ../features/peripheral-quirks.nix
    ../features/hardware-amd.nix
    ../features/flatpak.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "l";
}
