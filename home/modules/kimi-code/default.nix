{ config, lib, pkgs, ... }:
let
  inherit (lib)
    getExe
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  kimiCode = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "kimi-code";
    version = "0.27.0";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@moonshot-ai/kimi-code/-/kimi-code-${version}.tgz";
      hash = "sha256-qc9kB7RTrGm609YSuqaDim5dq2gMoui8fCTbFAV5qqA=";
    };

    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib/kimi-code" "$out/bin"
      cp -R . "$out/lib/kimi-code/"

      makeWrapper ${getExe pkgs.nodejs} "$out/bin/kimi" \
        --add-flags "$out/lib/kimi-code/dist/main.mjs"

      runHook postInstall
    '';

    meta = {
      description = "Agentic coding CLI from Moonshot AI";
      homepage = "https://code.kimi.com/";
      license = lib.licenses.mit;
      mainProgram = "kimi";
      platforms = pkgs.nodejs.meta.platforms;
    };
  };
in
{
  options.programs.kimiCode = {
    enable = mkEnableOption "Kimi Code CLI";

    package = mkOption {
      type = types.package;
      default = kimiCode;
      defaultText = "Kimi Code packaged from the pinned upstream npm release";
      description = "Package providing the `kimi` executable.";
    };
  };

  config = mkIf config.programs.kimiCode.enable {
    home.packages = [ config.programs.kimiCode.package ];
  };
}
