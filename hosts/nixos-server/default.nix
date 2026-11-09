{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./cooling.nix
    ./control-panel.nix
    ./launcher.nix
  ];

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
    editor = false;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # Existing HDDs contain data awaiting review. Never assemble them at boot yet.
  boot.swraid.enable = false;

  networking = {
    hostName = "nixos-server";
    useDHCP = false;
    interfaces.eno1 = {
      useDHCP = true;
      wakeOnLan = {
        enable = true;
        policy = [ "magic" ];
      };
    };
    firewall.enable = true;
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      AllowUsers = [ "luix-server" ];
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
    };
  };

  # Retain locally changed console/sudo passwords across rebuilds.
  users.mutableUsers = true;
  users.users.luix-server = {
    isNormalUser = true;
    uid = 1001;
    home = "/home/luix-server";
    description = "Luix server administrator";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGkm7jowhdR0AIH+2U/aqv69XK/rlnFNiTXNtYdUkkiQ luix@nixos"
    ];
  };
  security.sudo.wheelNeedsPassword = true;

  fileSystems."/srv/llm" = {
    device = "/dev/disk/by-uuid/e56daeca-ec40-4698-8c5c-a081ac23b515";
    fsType = "ext4";
    options = [
      "noatime"
      "nodev"
      "nosuid"
      "nofail"
      "x-systemd.device-timeout=10s"
    ];
  };
  # Future model services must require /srv/llm to be mounted before writing.
  services.fstrim.enable = true;

  services.smartd = {
    enable = true;
    defaults.autodetected = "-a -n standby,q";
    notifications = {
      mail.enable = false;
      wall.enable = false;
    };
  };

  environment.systemPackages = with pkgs; [
    btop
    ethtool
    lm_sensors
    pciutils
    smartmontools
    mdadm
    ntfs3g
    rsync
  ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  hardware.enableRedistributableFirmware = true;
  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
  system.stateVersion = "26.05";
}
