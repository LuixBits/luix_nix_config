{ inputs, lib, pkgs, ... }:
{
  imports = [
    ../common/base.nix
    ../features/hardware-amd.nix
    ../features/audio.nix
    ../features/pc-mass-storage.nix
    ../features/flatpak.nix
    ../features/gaming.nix
    ../features/simracing
    ../features/corsair-cooling
    ../features/strata
    inputs.spatial-input.nixosModules.default
    ./hardware-configuration.nix
  ];

  hardware.spatial-input.enable = true;
  hardware.spatial-input.wheel.enable = true;
  luix.simracing.enable = true;

  # Calls and games share this desktop's audio graph. Small playback requests
  # previously drove HDMI at 256 frames while Q9U capture ran at 1024 frames.
  # Prefer timing margin under game load over minimum monitoring latency.
  services.pipewire.extraConfig = {
    pipewire."60-desktop-audio-buffering"."context.properties" = {
      "default.clock.rate" = 48000;
      "default.clock.quantum" = 2048;
      "default.clock.min-quantum" = 2048;
    };
    pipewire-pulse."60-desktop-audio-buffering"."pulse.properties" = {
      "pulse.min.req" = "2048/48000";
      "pulse.min.frag" = "2048/48000";
      "pulse.min.quantum" = "2048/48000";
    };
  };

  # Override the shared Q9U rule's 1024-frame forced quantum on this desktop.
  services.pipewire.wireplumber.extraConfig."52-pc-q9u-buffering"."monitor.alsa.rules" = [
    {
      matches = [ { "node.name" = "~alsa_input.usb-Samson_Technologies_Samson_Q9U_.*"; } ];
      actions.update-props."node.force-quantum" = 2048;
    }
  ];

  # Preserve the live workaround that improved speech, including after login
  # or a service restart. Keep the saved voice preset available for later tuning.
  home-manager.users.luix.systemd.user.services.easyeffects.Service.ExecStartPost =
    lib.mkAfter [ "${pkgs.easyeffects}/bin/easyeffects --bypass 1" ];

  boot.initrd.availableKernelModules = [ "thunderbolt" ];
  boot.kernelParams = [
    # Work around firmware reboot behavior on this host.
    "reboot=efi"

    # This desktop's X670 USB-C controller failed to resume from runtime
    # suspend while attaching a dock. Keep dock peripherals active as well.
    "usbcore.autosuspend=-1"
  ];

  services.udev.extraRules = ''
    # Keep every AMD xHCI controller awake. This covers both the motherboard
    # rear USB-C port and the case USB-C port without relying on PCI addresses.
    ACTION=="add|bind|change", SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{class}=="0x0c0330", TEST=="power/control", ATTR{power/control}="on"
  '';

  services.strata = {
    enable = true;
    models = [
      "normal"
      "abliterated"
    ];
    defaultModel = "normal";
    host = "0.0.0.0";
    port = 8080;
    lanInterface = "enp75s0";
    allowedClients = [ "192.168.18.13/32" ];
    gpuDevice = "GPU-b029531ca159d189";
    cpuWorkers = 15;
    # Hermes requires at least 64K; OpenCode reads this limit from the API.
    contextSize = 65536;
  };

  environment.systemPackages = with pkgs; [
    dosfstools
    gparted
    pciutils
    rocmPackages.rocminfo
  ];

  system.stateVersion = "25.11";
}
