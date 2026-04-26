{ pkgs, ... }:
{
  imports = [
    ../common/base.nix
    ../features/peripheral-quirks.nix
    ../features/caldigit-ts5-plus.nix
    ../features/hardware-amd.nix
    ../features/flatpak.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "l";

  users.users.luix.extraGroups = [ "video" ];

  programs.light = {
    enable = true;
    brightnessKeys = {
      enable = true;
      minBrightness = 5;
    };
  };

  environment.systemPackages = with pkgs; [
    brightnessctl
  ];

  systemd.services.laptop-panel-min-brightness = {
    description = "Keep the laptop panel from restoring too dark";
    after = [ "systemd-backlight@backlight:amdgpu_bl1.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "laptop-panel-min-brightness" ''
        set -eu

        backlight=/sys/class/backlight/amdgpu_bl1
        [ -e "$backlight/brightness" ] || exit 0

        max="$(cat "$backlight/max_brightness")"
        current="$(cat "$backlight/brightness")"
        minimum="$((max * 25 / 100))"

        if [ "$current" -lt "$minimum" ]; then
          echo "$minimum" > "$backlight/brightness"
        fi
      '';
    };
  };
}
