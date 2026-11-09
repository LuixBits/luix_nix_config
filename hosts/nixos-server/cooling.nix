{ config, pkgs, ... }:
let
  driver = import ./nct6687d.nix {
    inherit pkgs;
    kernelPackages = config.boot.kernelPackages;
  };
  controller = "${pkgs.python3}/bin/python3 ${./fan-control.py}";
in
{
  # The stock nct6683 driver can read this MSI board but cannot control its fans.
  boot.blacklistedKernelModules = [ "nct6683" ];
  boot.extraModulePackages = [ driver ];
  boot.kernelModules = [ "nct6687" ];

  systemd.services.luix-fan-control = {
    description = "Luix server temperature-based fan control";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = controller;
      ExecStopPost = "${controller} --restore";
      # A sensor/control failure leaves firmware in charge until investigated.
      Restart = "no";
      TimeoutStopSec = 15;
      NoNewPrivileges = true;
      ProtectSystem = "full";
      ProtectHome = true;
      PrivateTmp = true;
      UMask = "0077";
    };
  };
}
