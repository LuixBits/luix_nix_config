{ config, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.cpu.intel.updateMicrocode = true;

  # Baseline NVIDIA setup for Intel+NVIDIA systems.
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    nvidiaSettings = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}
