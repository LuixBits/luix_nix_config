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

  systemd.user.services.easyeffects = {
    Install = {
      WantedBy = lib.mkForce [ ];
    };
  };
}
