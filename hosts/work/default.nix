{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../common/base.nix
    ../../audiofix.nix
    ../roles/work.nix
    ../features/hardware-intel.nix
    # ../features/work/pia-manual.nix
  ];

  # services.piaManual = {
  #   # Keep credentials out of git by storing them in /run/secrets/pia.env.
  #   envFile = "/run/secrets/pia.env";
  #   runAfterLoginForUser = "luiz";
  # };

  services.xserver.videoDrivers = lib.mkForce [
    "nvidia"
    "modesetting"
  ];

  # Ensure old DisplayLink modules never load on this host.
  boot.blacklistedKernelModules = [ "evdi" ];

  # The Surface Laptop Studio can report tablet/slate mode during display and
  # dock transitions. Libinput otherwise suspends its built-in keyboard and
  # touchpad on Wayland, leaving pointer movement or clicks apparently stuck.
  environment.etc."libinput/local-overrides.quirks".text = ''
    [Microsoft Surface Laptop Studio Built-In Peripherals]
    MatchName=*Microsoft Surface*
    MatchDMIModalias=dmi:*svnMicrosoftCorporation:*pnSurfaceLaptopStudio:*
    ModelTabletModeNoSuspend=1
  '';

  # Work around firmware reboot/power button issues on this host.
  boot.kernelParams = [ "reboot=efi" ];
  services.logind.settings.Login = {
    HandlePowerKey = "poweroff";
    HandlePowerKeyLongPress = "poweroff";
    PowerKeyIgnoreInhibited = true;
  };

  system.stateVersion = "25.11";
}
