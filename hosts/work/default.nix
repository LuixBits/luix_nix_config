{ lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../common/base.nix
    ../../audiofix.nix
    ../features/peripheral-quirks.nix
    ../features/hardware-intel.nix
    ../features/work/appimage.nix
    ../features/work/caddy.nix
    ../features/work/cx.nix
    ../features/work/db.nix
    # ../features/work/pia-manual.nix
  ];

  networking.hostName = "work";

  # services.piaManual = {
  #   # Keep credentials out of git by storing them in /run/secrets/pia.env.
  #   envFile = "/run/secrets/pia.env";
  #   runAfterLoginForUser = "luiz";
  # };

  # Shared common/base defines user `luix`; disable it on work to keep a single user.
  users.users.luix.enable = lib.mkForce false;

  services.flatpak.enable = true;
  services.xserver.videoDrivers = lib.mkForce [ "nvidia" "modesetting" ];

  # Ensure old DisplayLink modules never load on this host.
  boot.blacklistedKernelModules = [ "evdi" ];

  # Work around firmware reboot/power button issues on this host.
  boot.kernelParams = [ "reboot=efi" ];
  services.logind.settings.Login = {
    HandlePowerKey = "poweroff";
    HandlePowerKeyLongPress = "poweroff";
    PowerKeyIgnoreInhibited = true;
  };

  # Certificates are intentionally not committed to this repo.
  # Add them in a local, untracked module if needed.
  security.pki.certificateFiles = [ ];

  users.users.luiz = {
    isNormalUser = true;
    description = "Luiz";
    uid = 1000;
    home = "/home/luiz";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
  };

  nixpkgs.config = {
    allowUnsupportedSystem = true;
  };

  system.stateVersion = lib.mkForce "25.11";
}
