{ config, inputs, pkgs, ... }:
let
  pkgsUnstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config = {
      allowUnfree = true;
      allowUnsupportedSystem = true;
    };
  };
in
{
  imports = [
    ./optimisations.nix
  ];

  # -------- basics --------
  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_GB.UTF-8";
  networking.networkmanager.enable = true;
  networking.firewall.checkReversePath = false;

  boot.kernel.sysctl = {
    "vm.max_map_count" = 16777216;
    "fs.file-max" = 524288;
  };

  nixpkgs.overlays = [
    (final: prev: {
      atopile = prev.writeShellScriptBin "atopile" ''
        echo "Atopile placeholder; real package not available on this channel."
      '';
    })
  ];

  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_29;
    daemon.settings = {
      dns = [ "1.1.1.1" "8.8.8.8" ];
      features = {
        buildkit = true;
      };
    };
  };

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "exfat" ];

  # Display manager (SDDM) + X11 stack for the greeter
  services.xserver.enable = true;
  services.xserver.xkb = { layout = "ch"; variant = ""; };
  services.displayManager.sddm = {
    enable = true;
    settings = {
      General = {
        InputMethod = "";
      };
    };
  };
  services.displayManager.defaultSession = "niri";
  console.keyMap = "sg";

  services.printing.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.hardware.bolt.enable = true;

  # Keep bash as the login/recovery shell; interactive bash hands off to fish.
  environment.shells = with pkgs; [
    bashInteractive
    fish
  ];

  users.users.luix = {
    isNormalUser = true;
    description = "luix";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
    shell = pkgs.bashInteractive;
  };

  fonts.packages = with pkgs; [
    nerd-fonts.droid-sans-mono
    nerd-fonts.symbols-only
    nerd-fonts.bigblue-terminal
    nerd-fonts.heavy-data
    nerd-fonts.hurmit
    roboto
  ];

  # Program toggles
  programs.bazecor = {
    enable = true;
    package = pkgsUnstable.bazecor;
  };
  programs.dconf.enable = true;
  programs.bash.interactiveShellInit = ''
    # Launch fish for normal interactive shells, while keeping bash in /etc/passwd.
    if [[ $UID -eq 1000 && $SHLVL == [12] ]]; then
      read -r parent < /proc/$PPID/comm || parent=
      if [[ $parent != fish ]]; then
        SHELL=${pkgs.fish}/bin/fish exec ${pkgs.fish}/bin/fish
      fi
    fi
  '';
  programs.fish.enable = true; # expose fish system-wide without making it the login shell
  programs.xwayland.enable = true;
  programs.niri.enable = true; # Niri session in the display manager

  # The Defy exposes a CDC ACM serial interface for Bazecor. Keep modem probing
  # away from it so Bazecor can own the protocol handshake reliably.
  services.udev.extraRules = ''
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="35ef", ENV{ID_MM_DEVICE_IGNORE}="1"
  '';

  nixpkgs.config.allowUnfree = true;

  # Graphics (25.11 uses hardware.graphics.*)
  hardware.graphics = {
    enable = true;
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    warn-dirty = false;

    # Only local admins should be able to submit builds to the daemon.
    allowed-users = [ "@wheel" ];
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
    # Use niri's recommended portal preference order (niri-portals.conf).
    configPackages = [ pkgs.niri ];
  };

  # Needed for the Secret portal (Flatpak apps) and recommended by niri docs.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  environment.systemPackages = with pkgs; [
    exfatprogs
    usbutils
    wireguard-tools
    xwayland-satellite
  ];

  system.stateVersion = "25.11";
}
