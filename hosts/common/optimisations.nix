{ config, ... }:
{
  # Keep common values as the source of truth for all hosts.
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    flake = "/etc/nixos#${config.networking.hostName}";
    dates = "daily";
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 20d";
  };

  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };

  # Keep boot entry limit aligned across bootloaders.
  boot.loader.grub.configurationLimit = 10;
  boot.loader.systemd-boot.configurationLimit = 10;

  services.fwupd.enable = true;
  services.fstrim.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        FastConnectable = "true";
        Experimental = "true";
      };
      Policy = {
        AutoEnable = "true";
      };
    };
  };
  services.blueman.enable = true;

  nix.settings.auto-optimise-store = true;
}
