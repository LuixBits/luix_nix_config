{ pkgs, ... }:
let
  recoverTs5Plus = pkgs.writeShellScript "recover-caldigit-ts5-plus" ''
    set -u

    ${pkgs.kmod}/bin/modprobe xhci_pci || true
    ${pkgs.kmod}/bin/modprobe atlantic || true

    fix_pci_device() {
      dev="$1"
      driver="$2"
      slot="$(basename "$dev")"

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

      vendor="$(cat "$dev/vendor")"
      device="$(cat "$dev/device")"
      subsystem_vendor="$(cat "$dev/subsystem_vendor")"
      subsystem_device="$(cat "$dev/subsystem_device")"

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

      vendor="$(cat "$dev/vendor")"
      device="$(cat "$dev/device")"
      subsystem_vendor="$(cat "$dev/subsystem_vendor")"
      subsystem_device="$(cat "$dev/subsystem_device")"

      case "$vendor:$device:$subsystem_vendor:$subsystem_device" in
        0x1b21:0x2142:0x1ab6:0x3144)
          slot="$(basename "$dev")"

          if [ -w "$dev/power/control" ]; then
            echo on > "$dev/power/control" || true
          fi

          if [ -e "$dev/driver" ] && [ -w "$dev/driver/unbind" ]; then
            echo "$slot" > "$dev/driver/unbind" || true
            sleep 2
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
}
