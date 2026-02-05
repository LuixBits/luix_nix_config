{ pkgs, ... }:
{
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 4096;
        "default.clock.min-quantum" = 1024;
        "default.clock.max-quantum" = 4096;
      };
    };

    extraConfig.pipewire-pulse."99-no-flat-volume" = {
      "pulse.properties" = {
        "pulse.min.quantum" = "4096/48000";
        "pulse.flat-volume" = false;
      };
    };

    wireplumber.extraConfig."99-optical-fix" = {
      "monitor.alsa.rules" = [
        {
          "matches" = [
            { "node.name" = "~.*SPDIF.*"; }
            { "node.name" = "~.*optical.*"; }
            { "node.name" = "~.*iec958.*"; }
            { "node.name" = "~.*digital-stereo.*"; }
          ];
          "actions" = {
            "update-props" = {
              "api.alsa.soft-mixer" = true;
              "api.alsa.ignore-dB" = true;
            };
          };
        }
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    pipewire
    wireplumber
  ];

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1038", TEST=="power/control", ATTR{power/control}="on"
  '';
}
