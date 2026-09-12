{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.luix.simracing;
  boxflatRules = pkgs.writeText "70-boxflat.rules" ''
    ACTION!="remove", SUBSYSTEM=="tty", KERNEL=="ttyACM*", ATTRS{idVendor}=="346e", TAG+="uaccess"
    SUBSYSTEM=="misc", KERNEL=="uinput", OPTIONS+="static_node=uinput", TAG+="uaccess"
  '';
in
{
  imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

  options.luix.simracing = {
    enable = lib.mkEnableOption "MOZA simracing system support";
    vr.enable = lib.mkEnableOption "WiVRn and Steam OpenXR support" // {
      default = true;
    };
    vr.wireless = lib.mkEnableOption "WiVRn LAN discovery and streaming ports";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        programs.steam.enable = true;

        services.flatpak = {
          enable = true;
          # Retain the existing system installation and writable user data.
          packages = [ "io.github.lawstorant.boxflat" ];
          uninstallUnmanaged = false;
        };

        # MOZA's HID force-feedback driver is supplied by the host kernel.
        # CDC ACM is used for configuration; uinput supports Boxflat's fixes.
        boot.kernelModules = [
          "cdc_acm"
          "uinput"
        ];

        services.udev.packages = [
          (pkgs.runCommand "boxflat-udev-rules" { } ''
            # Apply active-session ACL tags before 73-seat-late.rules.
            # https://github.com/Lawstorant/boxflat/blob/main/udev/99-boxflat.rules
            install -Dm644 ${boxflatRules} "$out/lib/udev/rules.d/70-boxflat.rules"

            # Boxflat's startup check requires this exact filename as well.
            ln -s 70-boxflat.rules "$out/lib/udev/rules.d/99-boxflat.rules"
          '')
        ];
      }

      (lib.mkIf cfg.vr.enable {
        services.wivrn = {
          enable = true;
          autoStart = false;
          highPriority = true;
          openFirewall = cfg.vr.wireless;
          extraServerFlags = lib.optional (!cfg.vr.wireless) "--no-publish-service";
          steam = {
            enable = true;
            importOXRRuntimes = true;
          };
          # Keep WiVRn's settings writable and use its upstream encoder defaults.
        };

        services.avahi.openFirewall = lib.mkIf cfg.vr.wireless true;
      })
    ]
  );
}
