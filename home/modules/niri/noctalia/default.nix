{ inputs, pkgs, ... }:
let
  noctaliaPackage = pkgs.callPackage (inputs.noctalia + "/nix/package.nix") { };
in

{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;
    package = noctaliaPackage;
  };
}
