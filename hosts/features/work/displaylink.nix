{ config, pkgs, lib, ... }:

let
  driverUrl = "https://www.synaptics.com/sites/default/files/exe_files/2025-09/DisplayLink%20USB%20Graphics%20Software%20for%20Ubuntu6.2-EXE.zip";
  driverHash = "sha256-JQO7eEz4pdoPkhcn9tIuy5R4KyfsCniuw6eXw/rLaYE=";
in
{
  nixpkgs.overlays = [
    (final: prev: {
      displaylink = prev.displaylink.overrideAttrs (_old: {
        src = builtins.fetchurl {
          url = driverUrl;
          name = "displaylink-620.zip";
          sha256 = driverHash;
        };
      });
    })
  ];

  services.xserver.videoDrivers = lib.mkDefault [ "displaylink" "modesetting" ];

  boot.extraModulePackages = with config.boot.kernelPackages; lib.mkDefault [ evdi ];
  boot.initrd.kernelModules = lib.mkDefault [ "evdi" ];

  environment.systemPackages = lib.mkDefault [ pkgs.displaylink ];

  systemd.services.dlm = {
    # NixOS 25.11 + this DisplayLink packaging can leave dlm with no WantedBy,
    # so it never auto-starts and external displays stay black after login.
    wantedBy = [ "display-manager.service" ];

    # Keep DisplayLinkManager alive across rebuilds and recover quickly if it exits.
    restartIfChanged = false;
    stopIfChanged = false;

    serviceConfig = {
      Restart = lib.mkForce "always";
      RestartSec = lib.mkForce "1s";
      OOMScoreAdjust = -900;
    };

    unitConfig = {
      StartLimitIntervalSec = 0;
    };
  };
}
