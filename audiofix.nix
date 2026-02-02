{ ... }:
{
  # Audio (PipeWire baseline + minimal routing fixes)
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.extraConfig."10-settings" = {
      "wireplumber.settings" = {
        "device.restore-profile" = false;
        "device.restore-routes" = false;
      };
    };
    wireplumber.extraConfig."50-audio-routing" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "device.name" = "alsa_card.usb-SteelSeries_Arctis_Nova_Pro_Wireless-00"; }
          ];
          actions = {
            update-props = {
              "device.profile" = "output:analog-stereo+input:mono-fallback";
              "device.disabled-profiles" = [
                "output:iec958-stereo"
                "output:iec958-stereo+input:mono-fallback"
              ];
            };
          };
        }
        {
          matches = [
            { "node.name" = "alsa_output.usb-SteelSeries_Arctis_Nova_Pro_Wireless-00.iec958-stereo"; }
          ];
          actions = {
            update-props = {
              "priority.session" = 50;
            };
          };
        }
        {
          matches = [
            { "node.name" = "alsa_output.usb-SteelSeries_Arctis_Nova_Pro_Wireless-00.analog-stereo"; }
          ];
          actions = {
            update-props = {
              "priority.session" = 1100;
            };
          };
        }
        {
          matches = [
            { "node.name" = "alsa_output.usb-Elgato_Systems_Elgato_Wave_3_BS09L1A00858-00.iec958-stereo"; }
          ];
          actions = {
            update-props = {
              "node.disabled" = true;
            };
          };
        }
      ];
    };
  };
}
