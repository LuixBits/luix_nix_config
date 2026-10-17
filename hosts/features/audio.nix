{ pkgs, ... }:
{
  security.rtkit.enable = true;

  services = {
    pulseaudio.enable = false;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      jack.enable = true;
      pulse.enable = true;

      wireplumber.extraConfig."51-samson-q9u-recording" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              { "node.name" = "~alsa_input.usb-Samson_Technologies_Samson_Q9U_.*"; }
            ];
            actions.update-props = {
              # Give USB capture extra timing margin without disabling ALSA's
              # batch-device handling. 2048 frames add about 43 ms at 48 kHz.
              "api.alsa.headroom" = 2048;

              # Keep the microphone and its effects at 1024-frame blocks even
              # when a game or call requests a smaller processing quantum.
              "node.force-quantum" = 1024;
            };
          }
        ];
      };

      wireplumber.extraConfig."99-keep-alsa-devices-awake" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              { "node.name" = "~alsa_input.*"; }
            ];
            actions.update-props = {
              "session.suspend-timeout-seconds" = 0;
            };
          }
        ];
      };
    };

    udev.extraRules = ''
      # Keep call-critical USB audio/video devices and their dock path awake.
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1038", ATTR{idProduct}=="12e5", TEST=="power/control", ATTR{power/control}="on"
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="17a0", ATTR{idProduct}=="0243", TEST=="power/control", ATTR{power/control}="on"
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="3564", ATTR{idProduct}=="fef8", TEST=="power/control", ATTR{power/control}="on"
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="5412", TEST=="power/control", ATTR{power/control}="on"
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="0412", TEST=="power/control", ATTR{power/control}="on"
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="17ef", ATTR{idProduct}=="a356", TEST=="power/control", ATTR{power/control}="on"
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="17ef", ATTR{idProduct}=="1028", TEST=="power/control", ATTR{power/control}="on"
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="17ef", ATTR{idProduct}=="1029", TEST=="power/control", ATTR{power/control}="on"
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="17ef", ATTR{idProduct}=="a357", TEST=="power/control", ATTR{power/control}="on"
    '';
  };

  environment.systemPackages = with pkgs; [
    pipewire
    wireplumber
  ];
}
