{ pkgs, ... }:
let
  arctisProfile = pkgs.writeShellScript "wpctl-arctis-analog" ''
    set -euo pipefail
    WPCTL="${pkgs.pipewire}/bin/wpctl"
    AWK="${pkgs.gawk}/bin/awk"
    SLEEP="${pkgs.coreutils}/bin/sleep"

    # Find the Arctis device id
    for _i in $(seq 1 30); do
      dev_id="$($WPCTL status | $AWK '
        $0 ~ /Devices:/ {in=1; next}
        in && $0 ~ /Arctis Nova Pro Wireless/ {gsub(/\./,"",$1); print $1; exit}
      ')"
      if [ -n "$dev_id" ]; then
        $WPCTL set-profile "$dev_id" "output:analog-stereo+input:mono-fallback" || true
        break
      fi
      $SLEEP 1
    done

    # Find the analog sink and set it as default
    for _i in $(seq 1 30); do
      sink_id="$($WPCTL status | $AWK '
        $0 ~ /Sinks:/ {in=1; next}
        in && $0 ~ /Arctis Nova Pro Wireless/ && $0 ~ /Analog Stereo/ {gsub(/\./,"",$1); print $1; exit}
      ')"
      if [ -n "$sink_id" ]; then
        $WPCTL set-default "$sink_id" || true
        break
      fi
      $SLEEP 1
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

  systemd.user.services.pipewire-arctis-profile = {
    Unit = {
      Description = "Force Arctis Nova Pro Wireless to analog stereo profile";
      After = [ "pipewire.service" "wireplumber.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = arctisProfile;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
