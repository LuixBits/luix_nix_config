{ lib, modulesPath, ... }:
{
  # Virtual hardware for the bootable capture VM (nixos-install target).
  # Labels match what the install script creates on the attached disk.
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "xhci_pci"
  ];

  # OVMF has no writable EFI variables in this setup; systemd-boot installs
  # to the removable-media fallback path instead.
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  networking.useDHCP = lib.mkDefault true;
}
