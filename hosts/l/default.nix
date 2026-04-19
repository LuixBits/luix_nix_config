{ ... }:
{
  imports = [
    ../common/base.nix
    ../../audiofix.nix
    ../features/hardware-amd.nix
    ../features/flatpak.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "l";
}
