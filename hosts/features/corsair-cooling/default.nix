{
  config,
  lib,
  pkgs,
  ...
}:
let
  openLinkHub = pkgs.openlinkhub;
  applicationRoot = "${openLinkHub}/opt/OpenLinkHub";
  commanderSerial = "2060387A4231";
  curveName = "PcBalancedCPU";

  # The 7950X3D has an 89 C Tjmax: reach full cooling at 85 C, with a flat
  # idle region to avoid chasing small spikes. Keep the proven 40% fan minimum.
  curvePoints = [
    {
      temperature = 0;
      fans = 40;
      pump = 70;
    }
    {
      temperature = 55;
      fans = 40;
      pump = 70;
    }
    {
      temperature = 65;
      fans = 50;
      pump = 75;
    }
    {
      temperature = 75;
      fans = 65;
      pump = 85;
    }
    {
      temperature = 80;
      fans = 85;
      pump = 90;
    }
    {
      temperature = 85;
      fans = 100;
      pump = 100;
    }
  ];
  curveFile = pkgs.writeText "${curveName}.json" (
    builtins.toJSON {
      sensor = 0; # CPU, not coolant temperature.
      zeroRpm = false;
      linear = false;
      points = {
        "0" = map (p: {
          x = p.temperature;
          y = p.pump;
        }) curvePoints;
        "1" = map (p: {
          x = p.temperature;
          y = p.fans;
        }) curvePoints;
      };
      # Also provide conservative step values for OpenLinkHub's legacy mode.
      profiles = lib.imap0 (
        i: p:
        let
          next = builtins.elemAt curvePoints (lib.min (i + 1) (builtins.length curvePoints - 1));
        in
        {
          id = i + 1;
          min = p.temperature;
          max = if i + 1 < builtins.length curvePoints then next.temperature else 200;
          mode = 0;
          fans = next.fans;
          pump = next.pump;
        }
      ) curvePoints;
    }
  );
in
{
  assertions = [
    {
      assertion = config.networking.hostName == "pc";
      message = "hosts/features/corsair-cooling configures the pc's Corsair cooling controllers and must only be imported by the pc host.";
    }
  ];

  # The detected Commander Core is USB 1b1c:0c32. OpenLinkHub also supports
  # iCUE LINK hubs if one is connected. Its packaged rules give the
  # unprivileged service account access to Corsair USB devices.
  services.udev.packages = [ openLinkHub ];

  users.groups.openlinkhub = { };
  users.users.openlinkhub = {
    isSystemUser = true;
    group = "openlinkhub";
    description = "OpenLinkHub Corsair device controller";
  };

  environment.systemPackages = [ openLinkHub ];

  systemd.services.openlinkhub = {
    description = "Open source Corsair cooling and lighting controller";
    wantedBy = [ "multi-user.target" ];
    conflicts = [ "openlinkhub-emergency.service" ];
    after = [
      "local-fs.target"
      "openlinkhub-emergency.service"
      "systemd-udevd.service"
    ];

    # The upstream application expects its database, web assets, profiles, and
    # generated config.json below its working directory. Seed a writable state
    # directory while preserving any settings and profiles it creates later.
    preStart = ''
      install -d -m 0750 database static web

      cp --recursive --no-clobber --no-preserve=mode,ownership \
        ${applicationRoot}/database/. database/
      cp --recursive --force --no-preserve=mode,ownership \
        ${applicationRoot}/static/. static/
      cp --recursive --force --no-preserve=mode,ownership \
        ${applicationRoot}/web/. web/

      chmod -R u+rwX,go-rwx database static web

      # This named curve is managed by Nix and restored on each service start.
      install -d -m 0750 database/temperatures
      install -m 0640 ${curveFile} database/temperatures/${curveName}.json

      # Fresh OpenLinkHub state already defaults to automatic graph control.
      # Preserve existing settings while enforcing the modes this curve needs.
      if [ -f config.json ]; then
        cp --no-clobber config.json config.json.before-nix-cooling
        jq '.manual = false | .graphProfiles = true' config.json > config.json.tmp
        mv config.json.tmp config.json
      fi
    '';

    path = [
      pkgs.coreutils
      pkgs.pciutils
      pkgs.systemd
      pkgs.jq
    ];

    serviceConfig = {
      Type = "simple";
      User = "openlinkhub";
      Group = "openlinkhub";
      StateDirectory = "openlinkhub";
      StateDirectoryMode = "0750";
      WorkingDirectory = "/var/lib/openlinkhub";
      ExecStart = "${openLinkHub}/bin/OpenLinkHub";
      Restart = "on-failure";
      RestartSec = "5s";
      UMask = "0027";
    };
  };

  # Use the application's API to assign and save the curve without replacing
  # its device profiles (which also contain LCD, RGB and label settings).
  # A separate unit can retry readiness/USB failures without stopping cooling.
  systemd.services.openlinkhub-curve = {
    description = "Apply the pc's managed Corsair cooling curve";
    wantedBy = [ "openlinkhub.service" ];
    requires = [ "openlinkhub.service" ];
    after = [ "openlinkhub.service" ];
    partOf = [ "openlinkhub.service" ];
    path = [
      pkgs.curl
      pkgs.jq
    ];
    script = ''
      device='${commanderSerial}'
      profile='${curveName}'

      # Type=simple only guarantees that the process has started. Its config,
      # HTTP listener and USB devices may not be ready yet. Wait within this
      # start job so an ordinary startup does not make NixOS activation fail.
      deadline=$((SECONDS + 30))
      while true; do
        if port=$(jq -er '.listenPort' config.json 2>/dev/null); then
          api="http://127.0.0.1:$port/api"
          if snapshot=$(curl --fail --silent --max-time 2 "$api/devices/") &&
            jq -e --arg device "$device" '
              [.devices[$device].GetDevice.devices[]? | select(.HasSpeed)] | length > 0
            ' <<< "$snapshot" > /dev/null 2>&1; then
            break
          fi
        fi
        if (( SECONDS >= deadline )); then
          echo "Timed out waiting for OpenLinkHub and Commander Core $device." >&2
          exit 1
        fi
        sleep 1
      done

      payload=$(jq -nc --arg device "$device" --arg profile "$profile" \
        '{deviceId: $device, channelId: -1, profile: $profile}')
      response=$(curl --fail --silent --show-error --max-time 10 \
        --header 'Content-Type: application/json' --data "$payload" "$api/speed")
      if ! jq -e '.code == 200 and .status == 1' <<< "$response" > /dev/null; then
        echo "OpenLinkHub rejected the managed cooling curve: $response" >&2
        exit 1
      fi

      snapshot=$(curl --fail --silent --show-error --max-time 3 "$api/devices/")
      jq -e --arg device "$device" --arg profile "$profile" '
        .devices[$device].GetDevice as $controller |
        [$controller.devices[]? | select(.HasSpeed)] as $channels |
        ($channels | length > 0) and
        all($channels[];
          .profile == $profile and
          $controller.DeviceProfile.SpeedProfiles[(.channelId | tostring)] == $profile)
      ' <<< "$snapshot" > /dev/null
      echo "Applied $profile to all speed channels on Commander Core $device."
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "openlinkhub";
      Group = "openlinkhub";
      WorkingDirectory = "/var/lib/openlinkhub";
      Restart = "on-failure";
      RestartSec = "10s";
      # Covers the readiness wait plus the POST and verification requests.
      TimeoutStartSec = "60s";
    };
  };
}
