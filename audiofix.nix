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
    wireplumber.extraConfig."50-audio-routing" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "device.name" = "alsa_card.usb-SteelSeries_Arctis_Nova_Pro_Wireless-00"; }
          ];
          actions = {
            update-props = {
              "device.profile" = "output:analog-stereo+input:mono-fallback";
            };
          };
        }
        {
          matches = [
            { "node.name" = "alsa_output.usb-SteelSeries_Arctis_Nova_Pro_Wireless-00.iec958-stereo"; }
          ];
          actions = {
            update-props = {
              "node.disabled" = true;
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
