{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../common/base.nix
    ../../audiofix.nix
    ../features/virt-manager.nix
    ../features/work/appimage.nix
    ../features/work/cx.nix
    inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series
  ];

  networking.extraHosts = ''
    127.0.0.1 siga-webshop.local siga-blog.local roi.local webauth.local
  '';

  # Teams on the web uses Chrome's Idle Detection API to keep presence
  # accurate while another application is focused.
  environment.etc."opt/chrome/policies/managed/teams.json".text = builtins.toJSON {
    IdleDetectionAllowedForUrls = [ "https://teams.microsoft.com" ];
  };

  # common/base defines the personal `luix` account; Framework uses `luiz`.
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
      "video"
    ];
  };

  services.flatpak.enable = true;

  # The model-specific module supplies Framework EC, fingerprint, audio,
  # power, and the normal AMD graphics integration. Do not import the shared
  # ROCm desktop feature or any Intel/NVIDIA settings here.
  hardware.cpu.amd.updateMicrocode = true;
  services.xserver.videoDrivers = [ "amdgpu" ];

  environment.systemPackages = with pkgs; [
    brightnessctl
    pciutils
  ];

  assertions = [
    {
      assertion = !config.hardware.cpu.intel.updateMicrocode;
      message = "The AMD Framework host must not enable Intel CPU microcode.";
    }
    {
      assertion = lib.all (
        driver: driver != "intel" && driver != "nvidia"
      ) config.services.xserver.videoDrivers;
      message = "The AMD Framework host must not enable Intel or NVIDIA video drivers.";
    }
  ];

  system.stateVersion = "26.05";
}
