{ config, inputs, lib, pkgs, ... }:
let
  cfg = config.luix.godot;
  unstablePkgs = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.luix.godot = {
    enable = lib.mkEnableOption "the Godot 4 game development environment";

    package = lib.mkOption {
      type = lib.types.package;
      default = unstablePkgs.godot_4;
      defaultText = lib.literalExpression "inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.godot_4";
      description = "Godot editor package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
