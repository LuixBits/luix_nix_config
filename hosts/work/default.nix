{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../common/optimisations.nix
    ../features/hardware-intel-cpu.nix
    ../features/work/appimage.nix
    ../features/work/caddy.nix
    ../features/work/cx.nix
    ../features/work/db.nix
    ../features/work/displaylink.nix
    # ../features/work/pia-manual.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "work";
  networking.networkmanager.enable = true;

  # services.piaManual = {
  #   # Keep credentials out of git by storing them in /run/secrets/pia.env.
  #   envFile = "/run/secrets/pia.env";
  #   runAfterLoginForUser = "luiz";
  # };

  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;
  users.extraGroups.vboxusers.members = [ "luiz" ];

  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_GB.UTF-8";

  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.flatpak.enable = true;

  services.xserver.xkb = {
    layout = "ch";
    variant = "";
  };
  console.keyMap = "sg";

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Certificates are intentionally not committed to this repo.
  # Add them in a local, untracked module if needed.
  security.pki.certificateFiles = [ ];

  nix = {
    package = pkgs.nixVersions.stable;
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
    };
  };

  users.users.luiz = {
    isNormalUser = true;
    description = "Luiz";
    uid = 1000;
    home = "/home/luiz";
    extraGroups = [ "networkmanager" "wheel" "docker" "vboxusers" ];
  };

  programs.bazecor.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
    allowUnsupportedSystem = true;
  };

  system.stateVersion = "25.05";
}
