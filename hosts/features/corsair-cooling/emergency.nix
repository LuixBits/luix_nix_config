# Bring up cooling without realizing the complete NixOS closure. This is
# intentionally transient; the declarative service in ./default.nix replaces
# it on the next full NixOS activation.
#
# Exposed as a flake package so the pc can start it without a rebuild:
#   nix run .#openlinkhub-emergency
{
  lib,
  coreutils,
  openlinkhub,
  pciutils,
  sudo,
  systemd,
  writeShellApplication,
}:
let
  runtimePath = lib.makeBinPath [
    coreutils
    pciutils
    systemd
  ];
in
writeShellApplication {
  name = "openlinkhub-emergency";
  runtimeInputs = [
    coreutils
    sudo
    systemd
  ];
  text = ''
    if [[ "''${1:-}" == "--help" || "''${1:-}" == "-h" ]]; then
      echo "Start a temporary OpenLinkHub service without rebuilding NixOS."
      echo "The service lasts until it is stopped or the machine reboots."
      exit 0
    fi

    if (( EUID != 0 )); then
      exec sudo -- "$0" "$@"
    fi

    if systemctl is-active --quiet openlinkhub.service; then
      echo "The permanent OpenLinkHub service is already running."
      exit 0
    fi

    if systemctl is-active --quiet openlinkhub-emergency.service; then
      echo "The temporary OpenLinkHub service is already running."
      echo "Web UI: http://127.0.0.1:27003/"
      exit 0
    fi

    state_dir=/run/openlinkhub-emergency
    application_root=${openlinkhub}/opt/OpenLinkHub

    install -d -m 0700 \
      "$state_dir/database" \
      "$state_dir/static" \
      "$state_dir/web"

    cp --recursive --no-clobber --no-preserve=mode,ownership \
      "$application_root/database/." "$state_dir/database/"
    cp --recursive --force --no-preserve=mode,ownership \
      "$application_root/static/." "$state_dir/static/"
    cp --recursive --force --no-preserve=mode,ownership \
      "$application_root/web/." "$state_dir/web/"
    chmod -R u+rwX,go-rwx "$state_dir"

    systemd-run \
      --unit=openlinkhub-emergency.service \
      --collect \
      --description="Temporary OpenLinkHub cooling controller" \
      --property=WorkingDirectory="$state_dir" \
      --property=Restart=on-failure \
      --property=RestartSec=5s \
      --property=UMask=0077 \
      --property=NoNewPrivileges=true \
      --property=ProtectHome=true \
      --property=ProtectSystem=strict \
      --property=ReadWritePaths="$state_dir" \
      --setenv=PATH=${runtimePath} \
      ${openlinkhub}/bin/OpenLinkHub

    sleep 1
    if ! systemctl is-active --quiet openlinkhub-emergency.service; then
      journalctl --unit=openlinkhub-emergency.service --lines=50 --no-pager
      exit 1
    fi

    echo "Temporary OpenLinkHub service started."
    echo "Web UI: http://127.0.0.1:27003/"
    echo "Stop it with: sudo systemctl stop openlinkhub-emergency.service"
  '';
}
