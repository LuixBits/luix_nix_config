{ ... }:
{
  imports = [ ../../audiofix.nix ];

  # USB Link Power Management quirks for known flaky peripherals.
  #
  # Keep this limited to USB-level quirks. PCIe/USB4 dock handling belongs in
  # a dock-specific module so it does not perturb unrelated machines.
  boot.kernelParams = [
    "usbcore.quirks=1038:12e5:k,17ef:a356:k,17ef:1028:k,17ef:1029:k,17ef:a357:k,2188:5804:k,2188:551a:k,2188:552a:k,2188:551f:k,2188:7113:k,2188:ace1:k,8087:5787:k"
  ];
}
