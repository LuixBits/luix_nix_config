{ config, lib, pkgs, ... }:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  kimiCode = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "kimi-code";
    version = "0.27.0";

    src = pkgs.fetchurl {
      url = "https://code.kimi.com/kimi-code/binaries/${version}/kimi-code-linux-x64";
      hash = "sha256-7surRbwbmStkjEY4eglyw0D6x9iyVJYW8erOyQ5ZWjE=";
    };

    dontUnpack = true;

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];

    installPhase = ''
      runHook preInstall

      install -Dm755 "$src" "$out/bin/kimi"

      runHook postInstall
    '';

    meta = {
      description = "Agentic coding CLI from Moonshot AI";
      homepage = "https://code.kimi.com/";
      license = lib.licenses.unfree;
      mainProgram = "kimi";
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };
in
{
  options.programs.kimiCode = {
    enable = mkEnableOption "Kimi Code CLI";

    package = mkOption {
      type = types.package;
      default = kimiCode;
      defaultText = "Kimi Code packaged from the pinned upstream binary";
      description = "Package providing the `kimi` executable.";
    };
  };

  config = mkIf config.programs.kimiCode.enable {
    home.packages = [ config.programs.kimiCode.package ];
  };
}
