{ lib, ... }:
{
  # Bootable LuixBits capture host: the l laptop configuration on virtual
  # hardware, rebuildable from inside the VM so nixos-rebuild demos are real.
  imports = [
    ./common.nix
    ./vm-hardware.nix
    ./capture-extras.nix
  ];
}
