{ lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    playerctl
    pavucontrol
    pwvucontrol
  ];

  services.easyeffects = {
    enable = true;

    # EasyEffects 8 handles --load-preset as a one-shot command. Starting it
    # with both --service-mode and --load-preset makes the service exit after
    # loading, so load the preset separately after the daemon is ready.
    preset = "";

    extraPresets = {
      luix-voice = lib.importJSON ./presets/luix-voice.json;
    };
  };

  systemd.user.services.easyeffects.Service.ExecStartPost = [
    "${pkgs.coreutils}/bin/sleep 0.5"
    "${pkgs.easyeffects}/bin/easyeffects --load-preset luix-voice"
  ];
}
