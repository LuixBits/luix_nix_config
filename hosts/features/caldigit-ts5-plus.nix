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
          fix_pci_device "$dev" xhci_pci
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
in
{
  # The TS5 Plus is a Thunderbolt 5 dock. On this ThinkPad T14 Gen 5 AMD, its
  # tunneled PCIe devices can appear in D3cold and fail to bind during hotplug.
  boot.kernelPackages = pkgs.linuxPackages_6_19;
  boot.kernelModules = [
    "thunderbolt"
    "xhci_pci"
    "atlantic"
  ];

  boot.kernelParams = [
    "pcie_port_pm=off"
  ];

  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="2188", ATTR{idProduct}=="5804", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="2188", ATTR{idProduct}=="551a", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="2188", ATTR{idProduct}=="552a", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="2188", ATTR{idProduct}=="551f", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="2188", ATTR{idProduct}=="7113", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="2188", ATTR{idProduct}=="ace1", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="5787", TEST=="power/control", ATTR{power/control}="on"

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
}
