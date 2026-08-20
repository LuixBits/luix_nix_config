{ config, pkgs, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.cpu.intel.updateMicrocode = true;

  # Use the Intel iGPU's media engine for hardware video decoding and encoding.
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

  # Baseline NVIDIA setup for Intel+NVIDIA systems.
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    nvidiaSettings = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}
