{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.spatial-input;
in
{
  options.hardware.spatial-input = {
    enable = lib.mkEnableOption "Spatial Input hardware support";

    enableUdevRules = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Grant the active local session access to supported SpaceMouse hidraw devices.";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.enableUdevRules) {
    # This must sort before 73-seat-late.rules, where systemd applies uaccess
    # ACLs. services.udev.extraRules is emitted too late for TAG+="uaccess".
    services.udev.packages = [
      (pkgs.writeTextFile {
        name = "spatial-input-udev-rules";
        destination = "/lib/udev/rules.d/70-spatial-input.rules";
        text = ''
          ACTION!="remove", SUBSYSTEM=="hidraw", KERNEL=="hidraw*", ATTRS{idVendor}=="256f", ATTRS{idProduct}=="c633", ENV{ID_USB_INTERFACE_NUM}=="01", TAG+="uaccess"
        '';
      })
    ];
  };
}
