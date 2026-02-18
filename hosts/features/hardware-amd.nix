{ pkgs, ... }:
{
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.cpu.amd.updateMicrocode = true;

  # AMD OpenCL ICD used on your current desktops.
  hardware.graphics.extraPackages = with pkgs; [
    rocmPackages.clr.icd
  ];
}
