# modules/appimage.nix
{ pkgs, lib, ... }:

{
  programs.appimage = {
    enable = true;
    binfmt   = true;
    package  = pkgs.appimage-run.override {
      extraPkgs = pkgs: [
        # Add libraries commonly required by AppImages.
        pkgs.libdeflate
        pkgs.fuse
        pkgs.libGL
        pkgs.glib
        pkgs.bzip2
      ];
    };
  };
}
