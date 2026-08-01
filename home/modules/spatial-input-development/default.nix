{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.luix.spatialInputDevelopment;
in
{
  options.luix.spatialInputDevelopment.enable = lib.mkEnableOption "the Spatial Input Rust and Linux HID development environment";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      cargo
      clippy
      gcc
      gnumake
      jq
      nixfmt
      pkg-config
      python3
      rust-analyzer
      rustc
      rustfmt
      shellcheck
      taplo
    ];

    # hidapi's default Linux hidraw backend discovers libudev through pkg-config.
    home.sessionSearchVariables.PKG_CONFIG_PATH = [
      "${pkgs.udev.dev}/lib/pkgconfig"
    ];

    home.sessionVariables.RUST_SRC_PATH = pkgs.rustPlatform.rustLibSrc;
  };
}
