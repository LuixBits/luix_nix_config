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
    vr.usbNetworking = lib.mkEnableOption "native Meta Quest USB networking without ADB" // {
      default = true;
    };
    vr.wireless = lib.mkEnableOption "WiVRn streaming ports on LAN interfaces";
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
        # WiVRn's packaged dashboard already includes adb in its PATH for USB
        # connections. Expose the same tool for normal terminal diagnostics.
        environment.systemPackages = [ pkgs.android-tools ];

        services.wivrn = {
          enable = true;
          package = lib.mkDefault (pkgs.callPackage ./wivrn.nix { });
          # Start the managed service at login so the dashboard attaches to it
          # instead of spawning a server without the NixOS capability wrapper.
          autoStart = true;
          highPriority = true;
          openFirewall = cfg.vr.wireless;
          # Native USB networking also discovers the server through Avahi.
          extraServerFlags = lib.optional (!cfg.vr.wireless && !cfg.vr.usbNetworking) "--no-publish-service";
          steam = {
            enable = true;
            importOXRRuntimes = true;
          };
          # Keep WiVRn's settings writable and use its upstream encoder defaults.
        };

        services.avahi.openFirewall = lib.mkIf cfg.vr.wireless true;
      })

      (lib.mkIf (cfg.vr.enable && cfg.vr.usbNetworking) {
        assertions = [
          {
            assertion = config.networking.networkmanager.enable;
            message = "Simracing USB networking needs NetworkManager. Set luix.simracing.vr.usbNetworking = false to use another connection method.";
          }
          {
            assertion = config.networking.enableIPv6;
            message = "Meta Quest USB networking needs IPv6 link-local support.";
          }
        ];

        boot.kernelModules = [ "cdc_ncm" ];

        # Match the Meta USB network adapter independently of its USB port or
        # changing MAC address. .link files work with NetworkManager through
        # udev; this does not enable systemd-networkd.
        systemd.network.links."10-wivrn-usb" = {
          matchConfig = {
            Driver = "cdc_ncm";
            Property = "ID_VENDOR_ID=2833";
          };
          linkConfig = {
            NamePolicy = "";
            Name = "wivrn0";
          };
        };

        networking.networkmanager.ensureProfiles.profiles.wivrn-usb = {
          connection = {
            id = "WiVRn Quest USB";
            uuid = "bbea47d1-4d43-493a-b5bb-52b868c06743";
            type = "ethernet";
            interface-name = "wivrn0";
            autoconnect = true;
            autoconnect-priority = 100;
          };
          # The headset supplies an IPv6 link-local connection, without DHCP
          # or internet routing. Do not wait for an IPv4 lease.
          ipv4.method = "disabled";
          ipv6 = {
            method = "link-local";
            never-default = true;
          };
        };

        # Keep streaming restricted to the headset's USB link by default.
        networking.firewall.interfaces.wivrn0 = {
          allowedTCPPorts = [ 9757 ];
          allowedUDPPorts = [
            5353
            9757
          ];
        };
        services.avahi.ipv6 = true;
      })
    ]
  );
}
