{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  kimiCode = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.kimi-code;
in
{
  options.programs.kimiCode = {
    enable = mkEnableOption "Kimi Code CLI";

    package = mkOption {
      type = types.package;
      default = kimiCode;
      defaultText = "Kimi Code from the shared llm-agents flake input";
      description = "Package providing the `kimi` executable.";
    };
  };

  config = mkIf config.programs.kimiCode.enable {
    home.packages = [ config.programs.kimiCode.package ];
  };
}
