{ lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    playerctl
  ];

  services.easyeffects = {
    enable = true;
    preset = "luix-voice";

    extraPresets = {
      luix-voice = lib.importJSON ./presets/luix-voice.json;
    };
  };
}
