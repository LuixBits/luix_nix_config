{ config, pkgs, lib, inputs, ... }:
let
  sddmAstronautNoctalia = pkgs.sddm-astronaut.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      substituteInPlace $out/share/sddm/themes/sddm-astronaut-theme/metadata.desktop \
        --replace "ConfigFile=Themes/astronaut.conf" "ConfigFile=Themes/purple_leaves.conf"
    '';
  });
in
{
  # -------- imports --------
  imports = [ ./audiofix.nix ];

  # -------- basics --------
  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_GB.UTF-8";
  networking.networkmanager.enable = true;
  networking.firewall.checkReversePath = false;

  boot.kernel.sysctl = {
    "vm.max_map_count" = 16777216;
    "fs.file-max" = 524288;
  };

  # --- Updates & maintenance ---
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
    dates = ["weekly"];
  };

  nixpkgs.overlays = [
    (final: prev: {
      atopile = prev.writeShellScriptBin "atopile" ''
        echo "Atopile placeholder; real package not available on this channel."
      '';
    })
  ];

  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      dns = [ "1.1.1.1" "8.8.8.8" ];
      features = {
        # ensure buildkit on
        buildkit = true;
      };
    };
  };


  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "exfat" ];

  # Display manager (SDDM) + X11 stack for the greeter
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "amdgpu" ];
  services.xserver.xkb = { layout = "ch"; variant = ""; };
  services.displayManager.sddm = {
    enable = true;
    theme = "sddm-astronaut-theme";
    extraPackages = [ sddmAstronautNoctalia ];
    settings = {
      General = {
        InputMethod = "";
      };
      Theme = {
        Current = "sddm-astronaut-theme";
      };
    };
  };
  services.displayManager.defaultSession = "niri";
  console.keyMap = "sg";

  # Mount secondary NVMe (4TB, label LuixMass) under home
  fileSystems."/home/luix/Mass" = {
    device = "/dev/disk/by-uuid/270d2e79-7e41-4b83-8990-dad1412fcf45";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  # Ensure mountpoint exists with user-friendly ownership
  systemd.tmpfiles.rules = [
    "d /home/luix/Mass 0755 luix users -"
  ];

  # Printing
  services.printing.enable = true;

  # default Shell
  environment.shells = with pkgs; [ fish ];

  # Users
  users.users.luix = {
    isNormalUser = true;
    description = "luix";
    extraGroups = [
      "networkmanager"
      "wheel"
      "vboxusers"
      "libvirtd"
      "docker"
    ];
    shell = pkgs.fish;
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
  programs.steam.enable = true; # enables Steam and required 32-bit runtime
  programs.bazecor.enable = true;
  programs.fish.enable = true; # keep NixOS aware that fish is the login shell
  programs.xwayland.enable = true;
  programs.niri.enable = true; # Niri session in the display manager

  # Flatpak (system-wide)
  services.flatpak.enable = true;

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
    warn-dirty = false;

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

  # -------- Packages --------
  environment.systemPackages = with pkgs; [
    davinci-resolve-studio
    exfatprogs
    usbutils
    wireguard-tools
    xwayland-satellite
    #inputs.nix-citizen.packages.${pkgs.system}.star-citizen
    #inputs.nix-citizen.packages.${pkgs.system}.wine-astral
    #inputs.nix-citizen.packages.${pkgs.system}.lug-helper
    #inputs.nix-citizen.packages.${pkgs.system}.star-citizen-umu
    #inputs.nix-citizen.packages.${pkgs.system}.rsi-launcher-umu
  ];
  boot.kernelParams = [
    "usbcore.autosuspend=-1"
    "pcie_aspm=off"
    "usbcore.quirks=1038:12e5:k,17ef:a356:k,17ef:1028:k,17ef:1029:k,17ef:a357:k"
  ];
  system.stateVersion = "25.05";
}
