{ pkgs, kernelPackages }:

# Pin the driver with per-channel state restoration and a kernel-side lease.
# The nixpkgs version predates these protections.
kernelPackages.nct6687d.overrideAttrs (_: {
  version = "0-unstable-2026-11-07";
  src = pkgs.fetchFromGitHub {
    owner = "Fred78290";
    repo = "nct6687d";
    rev = "49ac9bced1771e73b9d5e3d50d5167167548efd4";
    hash = "sha256-aCnVaWI7yyLYaeeLZosuYxtOLXmMvWQRpMXfd0H6G1I=";
  };
})
