{ pkgs, ... }:
{
  programs.appimage = {
    enable = true;
    binfmt = true;
    package = pkgs.appimage-run.override {
      extraPkgs = pkgs: [
        pkgs.libdeflate
        pkgs.fuse
        pkgs.libGL
        pkgs.glib
        pkgs.bzip2
      ];
    };
  };
}
