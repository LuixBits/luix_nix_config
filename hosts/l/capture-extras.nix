{ lib, pkgs, ... }:
{
  # LuixBits screen-capture guest settings, shared by the shared-store
  # vmVariant and the bootable l-capture host. Nothing here runs on the
  # real laptop.
  services.displayManager.autoLogin = {
    enable = true;
    user = "luix";
  };

  services.openssh.enable = true;
  users.users.luix.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIEQmB4I1ySVo2fPaW1xUYLN2qtCB/Ech1NfuQ8OMasA luixbits-vm-capture"
  ];

  # No password prompts on camera: sudo-less rebuild demos, and autologin
  # cannot unlock the keyring anyway, so stop it from asking.
  security.sudo.wheelNeedsPassword = false;
  security.pam.services.sddm.enableGnomeKeyring = lib.mkForce false;
  services.gnome.gnome-keyring.enable = lib.mkForce false;

  # Tools the rebuild video demonstrates (chapter 5) plus wtype for
  # scripted typing during captures.
  environment.systemPackages = with pkgs; [
    nvd
    nix-output-monitor
    nh
    wtype
  ];
}
