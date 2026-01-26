{ pkgs, ... }:
let
  paKeepalive = pkgs.writeShellScript "pa-keepalive" ''
    set -euo pipefail
    PACTL="${pkgs.pulseaudio}/bin/pactl"
    PAREC="${pkgs.pulseaudio}/bin/parec"
    SLEEP="${pkgs.coreutils}/bin/sleep"

    while true; do
      sink="$($PACTL get-default-sink 2>/dev/null || true)"
      if [ -n "$sink" ]; then
        $PAREC --device="''${sink}.monitor" --raw --format=s16le --rate=48000 --channels=2 --latency-msec=200 >/dev/null || true
      fi
      $SLEEP 2
    done
  '';
in
{
  home.packages = with pkgs; [
    pavucontrol
    pamixer
    playerctl
    helvum
  ];

  systemd.user.services.pulseaudio-keepalive = {
    Unit = {
      Description = "Keep PulseAudio default sink active";
      After = [ "pulseaudio.service" ];
      Wants = [ "pulseaudio.service" ];
    };
    Service = {
      ExecStart = paKeepalive;
      Restart = "always";
      RestartSec = "2s";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
