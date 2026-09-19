{ pkgs, ... }:
{
  imports = [
    ../common/base.nix
    ../features/audio.nix
    ../features/flatpak.nix
  ];

  # Do not add a CalDigit TS5 Plus recovery service here. The previous
  # workaround made the dock worse; leave it to the kernel and firmware.

  programs.localsend = {
    enable = true;
    openFirewall = true;
  };

  systemd.tmpfiles.rules = [
    "d /home/luix/tablet-inbox 0755 luix users -"
  ];

  users.users.luix.extraGroups = [ "video" ];

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

  system.stateVersion = "25.11";
}
