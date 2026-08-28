{ lib, ... }:
{
  imports = [
    ../features/virt-manager.nix
    ../features/work/appimage.nix
    ../features/work/cx.nix
  ];

  networking.extraHosts = ''
    127.0.0.1 siga-webshop.local siga-blog.local roi.local webauth.local
  '';

  # common/base defines the personal `luix` account; Work machines use `luiz`.
  users.users.luix.enable = lib.mkForce false;
  users.users.luiz = {
    isNormalUser = true;
    description = "Luiz";
    uid = 1000;
    home = "/home/luiz";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
  };

  services.flatpak.enable = true;
}
