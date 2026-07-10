{ config, lib, pkgs, ... }:
let
  inherit (lib)
    getExe
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  sentryDeveloperCli = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "sentry";
    version = "0.38.0";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/sentry/-/sentry-${version}.tgz";
      hash = "sha512-jxW4P3bUqqeMo2dh8i7OpDsOwNe+GQZhE5Teazh+aTw0/nforhp3ZSBsmrm09kmRIUG2R4JrXMMS/8qYFLRCgg==";
    };

    nativeBuildInputs = [ pkgs.makeWrapper ];

    unpackPhase = ''
      runHook preUnpack
      tar -xzf "$src"
      sourceRoot=package
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib/sentry" "$out/bin"
      cp -R . "$out/lib/sentry/"
      chmod +x "$out/lib/sentry/dist/bin.cjs"

      makeWrapper ${getExe pkgs.nodejs} "$out/bin/sentry" \
        --add-flags "$out/lib/sentry/dist/bin.cjs"

      runHook postInstall
    '';

    meta = {
      description = "Sentry developer CLI";
      homepage = "https://cli.sentry.dev/";
      license = lib.licenses.fsl11Asl20;
      mainProgram = "sentry";
      platforms = pkgs.nodejs.meta.platforms;
    };
  };
in
{
  options.programs.sentryCli = {
    enable = mkEnableOption "Sentry developer CLI";

    package = mkOption {
      type = types.package;
      default = sentryDeveloperCli;
      defaultText = "Sentry developer CLI packaged from the upstream npm tarball";
      description = ''
        Package providing the `sentry` executable used by luixbits-sentry.nvim.
      '';
    };
  };

  config = mkIf config.programs.sentryCli.enable {
    home.packages = [ config.programs.sentryCli.package ];
  };
}
