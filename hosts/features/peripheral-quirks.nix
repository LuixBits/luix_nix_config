{ ... }:
{
  imports = [ ../../audiofix.nix ];

  # USB power/quirk settings for your current peripherals.
  boot.kernelParams = [
    "usbcore.autosuspend=-1"
    "pcie_aspm=off"
    "usbcore.quirks=1038:12e5:k,17ef:a356:k,17ef:1028:k,17ef:1029:k,17ef:a357:k"
  ];
}
