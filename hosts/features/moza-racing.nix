{
  config,
  inputs,
  pkgs,
  ...
}:
{
  imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

  assertions = [
    {
      assertion = config.networking.hostName == "pc";
      message = "hosts/features/moza-racing.nix configures the pc's MOZA racing hardware and must only be imported by the pc host.";
    }
  ];

  services.flatpak = {
    enable = true;
    packages = [ "io.github.lawstorant.boxflat" ];
    # Keep manually installed applications and remotes, including CrealityPrint.
    uninstallUnmanaged = false;
  };

  # Boxflat uses CDC ACM serial devices for configuration and uinput for
  # its optional game-detection fixes. MOZA FFB support is in our 6.18 kernel.
  boot.kernelModules = [
    "cdc_acm"
    "uinput"
  ];

  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "boxflat-udev-rules";
      destination = "/lib/udev/rules.d/70-boxflat.rules";
      # Adapt upstream's rules to active-session ACLs. The tags must be set
      # before systemd's 73-seat-late.rules applies uaccess permissions.
      # https://github.com/Lawstorant/boxflat/blob/main/udev/99-boxflat.rules
      text = ''
        ACTION!="remove", SUBSYSTEM=="tty", KERNEL=="ttyACM*", ATTRS{idVendor}=="346e", TAG+="uaccess"
        SUBSYSTEM=="misc", KERNEL=="uinput", OPTIONS+="static_node=uinput", TAG+="uaccess"
      '';
    })
  ];
}
