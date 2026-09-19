{ ... }:
{
  imports = [
    ./common.nix
    ../features/hardware-amd.nix
    ./hardware-configuration.nix
    ./vm.nix
  ];
}
