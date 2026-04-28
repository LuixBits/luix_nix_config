{ ... }:
let
  usbNoLpmQuirks = [
    # SteelSeries Arctis Nova Pro Wireless.
    "1038:12e5:k"

    # Lenovo USB-C dock IDs used on other hosts.
    "17ef:a356:k"
    "17ef:1028:k"
    "17ef:1029:k"
    "17ef:a357:k"

    # CalDigit TS5 Plus controllers and hub paths.
    "2188:5804:k"
    "2188:551a:k"
    "2188:552a:k"
    "2188:551f:k"
    "2188:7113:k"
    "2188:ace1:k"
    "2188:2175:k"
    "2188:2174:k"
    "2188:2075:k"
    "2188:2074:k"
    "8087:5787:k"

    # Downstream Realtek hubs and dock-attached devices that timed out.
    "0bda:5412:k"
    "0bda:0412:k"
    "0bda:1100:k"
    "3564:fef8:k"
    "046d:c08a:k"
  ];

  usbPowerIds = [
    # TS5 Plus Thunderbolt/USB hub controllers seen across TB4/TB5 hosts.
    { vendor = "2188"; product = "5804"; }
    { vendor = "2188"; product = "551a"; }
    { vendor = "2188"; product = "552a"; }
    { vendor = "2188"; product = "551f"; }
    { vendor = "2188"; product = "7113"; }
    { vendor = "2188"; product = "ace1"; }
    { vendor = "2188"; product = "2175"; }
    { vendor = "2188"; product = "2174"; }
    { vendor = "2188"; product = "2075"; }
    { vendor = "2188"; product = "2074"; }

    # Hubs/controllers commonly exposed behind the TS5 Plus on this setup.
    { vendor = "8087"; product = "5787"; }
    { vendor = "0bda"; product = "5412"; }
    { vendor = "0bda"; product = "0412"; }
    { vendor = "0bda"; product = "1100"; }

    # Devices that were timing out while attached through the dock.
    { vendor = "1038"; product = "12e5"; }
    { vendor = "3564"; product = "fef8"; }
    { vendor = "046d"; product = "c08a"; }
  ];

  powerRule =
    { vendor, product }:
    ''ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="${vendor}", ATTR{idProduct}=="${product}", TEST=="power/control", ATTR{power/control}="on"'';

  # Keep runtime power management disabled for any USB device below the
  # CalDigit dock. This covers devices whose own USB IDs change because they
  # are plugged into the dock later.
  caldigitChildPowerRule =
    ''ACTION=="add|change", SUBSYSTEM=="usb", ATTRS{idVendor}=="2188", TEST=="power/control", ATTR{power/control}="on"'';
in
{
  imports = [ ../../audiofix.nix ];

  # USB Link Power Management quirks for known flaky peripherals.
  #
  # Keep this limited to USB-level quirks. PCIe/USB4 dock handling belongs in
  # a dock-specific module so it does not perturb unrelated machines.
  boot.kernelParams = [
    "usbcore.quirks=${builtins.concatStringsSep "," usbNoLpmQuirks}"
  ];

  services.udev.extraRules = builtins.concatStringsSep "\n" (
    [ caldigitChildPowerRule ] ++ map powerRule usbPowerIds
  );
}
