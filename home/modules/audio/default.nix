{ lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    playerctl
    pavucontrol
    pwvucontrol
  ];

  services.easyeffects = {
    enable = true;
    preset = "luix-voice";

    extraPresets = {
      luix-voice = lib.importJSON ./presets/luix-voice.json;
    };
  };

  # Keep EasyEffects available for OBS even if GUI display variables are late.
  systemd.user.services.easyeffects = {
    Unit = {
      After = [
        "graphical-session.target"
        "pipewire.service"
        "wireplumber.service"
      ];
      Wants = [
        "pipewire.service"
        "wireplumber.service"
      ];
    };
    Service = {
      Restart = lib.mkForce "always";
      RestartSec = lib.mkForce 2;
    };
  };
}
