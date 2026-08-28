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
    ../roles/work.nix
    inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series
  ];

  users.users.luiz.extraGroups = [ "video" ];

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
