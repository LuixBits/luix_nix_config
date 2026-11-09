{
  lib,
  stdenvNoCC,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  writeShellApplication,
  python3,
  git,
  ripgrep,
  baseURL ? "http://192.168.18.10:8080/v1",
}:
let
  opencode = stdenvNoCC.mkDerivation {
    pname = "opencode-local-runtime";
    version = "1.15.7";
    src = fetchurl {
      url = "https://registry.npmjs.org/opencode-linux-x64-baseline/-/opencode-linux-x64-baseline-1.15.7.tgz";
      hash = "sha512-Tb52t7VFA/1lEFV0+In9VRDC3+r2iuIzlrR2BYZIEBAA+wRos4H1H/AJXP7VJEMMx1T/YCCEtT/fg1avObmNAA==";
    };
    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib ];
    dontStrip = true;
    installPhase = ''
      install -Dm755 bin/opencode "$out/bin/opencode"
    '';
    meta.platforms = [ "x86_64-linux" ];
  };
in
writeShellApplication {
  name = "opencode-local";
  runtimeInputs = [
    python3
    git
    ripgrep
  ];
  text = ''
    export STRATA_DEFAULT_BASE_URL=${lib.escapeShellArg baseURL}
    exec ${python3}/bin/python3 ${./client.py} ${opencode}/bin/opencode "$@"
  '';
  meta.description = "Independent OpenCode client for the currently active local Strata model";
}
