{ networkHostName, ... }:
{
  # Keep common values as the source of truth for all hosts.
  # /etc/nixos points to a user-owned local Git checkout. The root-owned
  # auto-upgrade service cannot safely fetch it, so keep upgrades explicit
  # through buildall/flakeonly instead.
  system.autoUpgrade = {
    enable = false;
    allowReboot = false;
    flake = "/etc/nixos#${networkHostName}";
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
