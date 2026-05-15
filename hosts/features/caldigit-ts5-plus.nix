{ pkgs, ... }:
let
  recoverTs5Plus = pkgs.writeShellScript "recover-caldigit-ts5-plus" ''
    set -u

    ${pkgs.kmod}/bin/modprobe xhci_pci || true
    ${pkgs.kmod}/bin/modprobe atlantic || true

    fix_pci_device() {
      dev="$1"
      driver="$2"
      slot="$(${pkgs.coreutils}/bin/basename "$dev")"

      if [ -w "$dev/power/control" ]; then
        echo on > "$dev/power/control" || true
      fi

      if [ -w "$dev/enable" ]; then
        echo 1 > "$dev/enable" || true
      fi

      if [ ! -e "$dev/driver" ] && [ -w "/sys/bus/pci/drivers/$driver/bind" ]; then
        echo "$slot" > "/sys/bus/pci/drivers/$driver/bind" || true
      fi
    }

    for dev in /sys/bus/pci/devices/*; do
      [ -r "$dev/vendor" ] || continue
      [ -r "$dev/device" ] || continue
      [ -r "$dev/subsystem_vendor" ] || continue
      [ -r "$dev/subsystem_device" ] || continue

      vendor="$(< "$dev/vendor")"
      device="$(< "$dev/device")"
      subsystem_vendor="$(< "$dev/subsystem_vendor")"
      subsystem_device="$(< "$dev/subsystem_device")"

      case "$vendor:$device:$subsystem_vendor:$subsystem_device" in
        0x1b21:0x2142:0x1ab6:0x3144)
          fix_pci_device "$dev" xhci_hcd
          ;;
        0x1d6a:0x04c0:0x1ab6:0x0173)
          fix_pci_device "$dev" atlantic
          ;;
      esac
    done

    if [ -w /sys/bus/pci/rescan ]; then
      echo 1 > /sys/bus/pci/rescan || true
    fi
  '';

  resetTs5PlusUsb = pkgs.writeShellScript "reset-caldigit-ts5-plus-usb" ''
    set -u

    ${pkgs.kmod}/bin/modprobe xhci_pci || true

    for dev in /sys/bus/pci/devices/*; do
      [ -r "$dev/vendor" ] || continue
      [ -r "$dev/device" ] || continue
      [ -r "$dev/subsystem_vendor" ] || continue
      [ -r "$dev/subsystem_device" ] || continue

      vendor="$(< "$dev/vendor")"
      device="$(< "$dev/device")"
      subsystem_vendor="$(< "$dev/subsystem_vendor")"
      subsystem_device="$(< "$dev/subsystem_device")"

      case "$vendor:$device:$subsystem_vendor:$subsystem_device" in
        0x1b21:0x2142:0x1ab6:0x3144)
          slot="$(${pkgs.coreutils}/bin/basename "$dev")"

          if [ -w "$dev/power/control" ]; then
            echo on > "$dev/power/control" || true
          fi

          if [ -w "$dev/enable" ]; then
            echo 1 > "$dev/enable" || true
          fi

          if [ -e "$dev/driver" ] && [ -w "$dev/driver/unbind" ]; then
            echo "$slot" > "$dev/driver/unbind" || true
            ${pkgs.coreutils}/bin/sleep 2
          fi

          if [ -w /sys/bus/pci/drivers/xhci_hcd/bind ]; then
            echo "$slot" > /sys/bus/pci/drivers/xhci_hcd/bind || true
          fi
          ;;
      esac
    done

    if [ -w /sys/bus/pci/rescan ]; then
      echo 1 > /sys/bus/pci/rescan || true
    fi

    ${recoverTs5Plus} || true
  '';

  watchTs5PlusUsb = pkgs.writeShellScript "watch-caldigit-ts5-plus-usb" ''
    set -u

    cooldown_seconds=90
    hub_window_seconds=45
    hub_error_threshold=3
    last_reset=0
    hub_first_error=0
    hub_error_count=0

    now_seconds() {
      ${pkgs.coreutils}/bin/date +%s
    }

    is_ts5_usb_device() {
      dev="$1"

      [ -e "$dev" ] || return 1
      dev="$(${pkgs.coreutils}/bin/readlink -f "$dev" 2>/dev/null || true)"

      while [ -n "$dev" ] && [ "$dev" != "/" ]; do
        if [ -r "$dev/idVendor" ]; then
          vendor="$(< "$dev/idVendor")"
          product=""
          if [ -r "$dev/idProduct" ]; then
            product="$(< "$dev/idProduct")"
          fi

          case "$vendor:$product" in
            2188:*|8087:5787)
              return 0
              ;;
          esac
        fi

        parent="$(${pkgs.coreutils}/bin/dirname "$dev")"
        [ "$parent" = "$dev" ] && break
        dev="$parent"
      done

      return 1
    }

    is_ts5_xhci_line() {
      line="$1"

      for dev in /sys/bus/pci/devices/*; do
        [ -r "$dev/vendor" ] || continue
        [ -r "$dev/device" ] || continue
        [ -r "$dev/subsystem_vendor" ] || continue
        [ -r "$dev/subsystem_device" ] || continue

        vendor="$(< "$dev/vendor")"
        device="$(< "$dev/device")"
        subsystem_vendor="$(< "$dev/subsystem_vendor")"
        subsystem_device="$(< "$dev/subsystem_device")"

        case "$vendor:$device:$subsystem_vendor:$subsystem_device" in
          0x1b21:0x2142:0x1ab6:0x3144)
            slot="$(${pkgs.coreutils}/bin/basename "$dev")"
            case "$line" in
              *"$slot"*)
                return 0
                ;;
            esac
            ;;
        esac
      done

      return 1
    }

    reset_with_cooldown() {
      reason="$1"
      now="$(now_seconds)"

      if [ $((now - last_reset)) -lt "$cooldown_seconds" ]; then
        return 0
      fi

      last_reset="$now"
      echo "CalDigit TS5 Plus USB watchdog: resetting dock USB controller after: $reason" >&2
      ${pkgs.coreutils}/bin/sleep 3
      ${resetTs5PlusUsb} || true
    }

    handle_hub_timeout() {
      line="$1"
      hub_device="''${line#hub }"
      hub_device="''${hub_device%%:*}"

      is_ts5_usb_device "/sys/bus/usb/devices/$hub_device" || return 0

      now="$(now_seconds)"
      if [ "$hub_first_error" -eq 0 ] || [ $((now - hub_first_error)) -gt "$hub_window_seconds" ]; then
        hub_first_error="$now"
        hub_error_count=1
      else
        hub_error_count=$((hub_error_count + 1))
      fi

      if [ "$hub_error_count" -ge "$hub_error_threshold" ]; then
        hub_first_error=0
        hub_error_count=0
        reset_with_cooldown "$line"
      fi
    }

    handle_xhci_fault() {
      line="$1"

      is_ts5_xhci_line "$line" || return 0
      reset_with_cooldown "$line"
    }

    recover_stale_xhci() {
      for dev in /sys/bus/pci/devices/*; do
        [ -r "$dev/vendor" ] || continue
        [ -r "$dev/device" ] || continue
        [ -r "$dev/subsystem_vendor" ] || continue
        [ -r "$dev/subsystem_device" ] || continue

        vendor="$(< "$dev/vendor")"
        device="$(< "$dev/device")"
        subsystem_vendor="$(< "$dev/subsystem_vendor")"
        subsystem_device="$(< "$dev/subsystem_device")"

        case "$vendor:$device:$subsystem_vendor:$subsystem_device" in
          0x1b21:0x2142:0x1ab6:0x3144)
            enabled=1
            if [ -r "$dev/enable" ]; then
              enabled="$(< "$dev/enable")"
            fi

            if [ "$enabled" != 1 ] || [ ! -e "$dev/driver" ]; then
              reset_with_cooldown "TS5 xHCI controller is present but not enabled or bound"
            fi
            ;;
        esac
      done
    }

    echo "CalDigit TS5 Plus USB watchdog: watching kernel log for dock USB failures" >&2
    recover_stale_xhci

    ${pkgs.systemd}/bin/journalctl -k -f -n 0 -o cat | while IFS= read -r line; do
      case "$line" in
        hub\ *"hub_ext_port_status failed (err = -110)"*)
          handle_hub_timeout "$line"
          ;;
        *"xHCI host controller not responding, assume dead"*|*"HC died; cleaning up"*)
          handle_xhci_fault "$line"
          ;;
        *"Unable to change power state from D3cold to D0, device inaccessible"*|*"BAR 0"*"not claimed; can't enable device"*|*"xHCI HW not ready after 5 sec"*|*"can't setup: -19"*|*"init "*" fail, -19"*)
          handle_xhci_fault "$line"
          ;;
      esac
    done
  '';
in
{
  # The TS5 Plus is a Thunderbolt 5 dock. On this ThinkPad T14 Gen 5 AMD, its
  # tunneled PCIe devices can appear in D3cold and fail to bind during hotplug.
  boot.kernelModules = [
    "thunderbolt"
    "xhci_pci"
    "atlantic"
  ];

  boot.kernelParams = [
    "pcie_port_pm=off"
    "pcie_aspm=off"
    "usbcore.autosuspend=-1"
  ];

  services.udev.extraRules = ''
    # Keep the whole TS5 Plus USB tree out of runtime suspend. The dock exposes
    # multiple internal hubs; ATTRS walks parent devices, so this also covers
    # keyboards, mice, audio devices, cameras, and other peripherals connected
    # downstream of those hubs without matching every device by product ID.
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="2188", TEST=="power/control", ATTR{power/control}="on", TEST=="power/autosuspend", ATTR{power/autosuspend}="-1"
    ACTION=="add|change", SUBSYSTEM=="usb", ATTRS{idVendor}=="2188", TEST=="power/control", ATTR{power/control}="on", TEST=="power/autosuspend", ATTR{power/autosuspend}="-1"

    # One TS5 internal USB3 branch appears as an Intel hub before the CalDigit
    # hub, so keep that branch awake as well.
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="5787", TEST=="power/control", ATTR{power/control}="on", TEST=="power/autosuspend", ATTR{power/autosuspend}="-1"
    ACTION=="add|change", SUBSYSTEM=="usb", ATTRS{idVendor}=="8087", ATTRS{idProduct}=="5787", TEST=="power/control", ATTR{power/control}="on", TEST=="power/autosuspend", ATTR{power/autosuspend}="-1"

    ACTION=="add|change", SUBSYSTEM=="pci", ATTR{vendor}=="0x1b21", ATTR{device}=="0x2142", ATTR{subsystem_vendor}=="0x1ab6", ATTR{subsystem_device}=="0x3144", TEST=="power/control", ATTR{power/control}="on", TAG+="systemd", ENV{SYSTEMD_WANTS}+="caldigit-ts5-plus-recover.service"
    ACTION=="add|change", SUBSYSTEM=="pci", ATTR{vendor}=="0x1d6a", ATTR{device}=="0x04c0", ATTR{subsystem_vendor}=="0x1ab6", ATTR{subsystem_device}=="0x0173", TEST=="power/control", ATTR{power/control}="on", TAG+="systemd", ENV{SYSTEMD_WANTS}+="caldigit-ts5-plus-recover.service"
  '';

  systemd.services.caldigit-ts5-plus-recover = {
    description = "Recover CalDigit TS5 Plus PCIe tunnel devices";
    after = [ "bolt.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = recoverTs5Plus;
    };
  };

  systemd.services.caldigit-ts5-plus-usb-reset = {
    description = "Reset CalDigit TS5 Plus USB controller";
    after = [ "bolt.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = resetTs5PlusUsb;
    };
  };

  systemd.services.caldigit-ts5-plus-usb-watchdog = {
    description = "Automatically reset CalDigit TS5 Plus USB controller after kernel faults";
    after = [
      "systemd-journald.service"
      "bolt.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = watchTs5PlusUsb;
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
