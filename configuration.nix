{ config, pkgs, lib, inputs, ... }:

{
  # -------- imports --------
  imports = [
    ./hardware-configuration.nix
  ];

  # -------- basics --------
  networking.hostName = "nixos";
  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_GB.UTF-8";
  networking.networkmanager.enable = true;

  boot.kernel.sysctl = {
    "vm.max_map_count" = 16777216;
    "fs.file-max" = 524288;
  };

  # --- Updates & maintenance ---
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    flake = "/etc/nixos#nixos";
    dates = "daily";
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 20d";
  };

  nix.optimise = {
    automatic = true;
    dates = ["weekly"];
  };

  nixpkgs.overlays = [
    inputs.nixvim.overlays.default
    (final: prev: {
      atopile = prev.writeShellScriptBin "atopile" ''
        echo "Atopile placeholder; real package not available on this channel."
      '';
    })
  ];

virtualisation.libvirtd.enable = true;
programs.virt-manager.enable = true;


  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  # GNOME on NixOS 25.05 (xserver paths)
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "amdgpu" ];
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.xserver.xkb = { layout = "ch"; variant = ""; };
  console.keyMap = "sg";

  # Printing
  services.printing.enable = true;

  # Audio (PipeWire)
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # default Shell
  environment.shells = with pkgs; [ zsh ];

  # Users
  users.users.luix = {
    isNormalUser = true;
    description = "luix";
    extraGroups = [ "networkmanager" "wheel" "vboxusers" "libvirtd" ];
    shell = pkgs.zsh;
  };

  #fonts
  fonts.packages = with pkgs; [
    #nerdfonts
    nerd-fonts.droid-sans-mono
    nerd-fonts.symbols-only
    nerd-fonts.bigblue-terminal
    nerd-fonts.heavy-data
    nerd-fonts.hurmit


    #other fonts
    roboto
    #mulish
    #bebas-neue
    #drois-sans-mono
  ];

  # Program toggles
  programs.steam.enable = true; # provides system-wide 32-bit libs; package lives in Home Manager
  programs.bazecor.enable = true;
  programs.zsh.enable = true; # keep NixOS aware that zsh is the login shell

  # Unfree ok
  nixpkgs.config.allowUnfree = true;

  # --- Hardware & firmware ---
  hardware.cpu.amd.updateMicrocode = true;
  services.fwupd.enable = true;
  services.fstrim.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Graphics (25.05 uses hardware.graphics.*)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;   # needed for 32-bit DX9 via Wine/DXVK
  };

  # Optional AMD OpenCL ICD (you had this earlier)
  hardware.graphics.extraPackages = with pkgs; [
    rocmPackages.clr.icd
  ];

  # -------- Nix settings + caches --------
  nix.settings = {
    # Keep flakes UX nice everywhere
    experimental-features = [ "nix-command" "flakes" ];

    # Caches from nix-citizen + nix-gaming READMEs
    substituters = [
      "https://nix-citizen.cachix.org"
      "https://nix-gaming.cachix.org"
    ];
    trusted-public-keys = [
      "nix-citizen.cachix.org-1:lPMkWc2X8XD4/7YPEEwXKKBg+SVbYTVrAaLA2wQTKCo="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    ];
    auto-optimise-store = true;
  };

  # -------- Packages --------
  environment.systemPackages = with pkgs; [
    davinci-resolve-studio
    inputs.nix-citizen.packages.${pkgs.system}.star-citizen
  ];
  system.stateVersion = "25.05";
}
