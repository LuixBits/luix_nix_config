{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:
pkgs.stdenv.mkDerivation {
  pname = "devin-cli";
  version = "3000.11.234";
  src = pkgs.fetchurl {
    url = "https://static.devin.ai/cli/3000.11.234/devin-3000.11.234-x86_64-unknown-linux.tar.gz";
    sha256 = "201370cddd2924294e3ca6b46fd8ece49b5763953b644a1dd823fce5490cb41a";
  };
  sourceRoot = ".";
  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
  buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.openssl pkgs.zlib ];
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R bin share "$out/"
    runHook postInstall
  '';
  meta = {
    description = "Cognition Devin CLI, pinned official Linux distribution";
    homepage = "https://devin.ai/cli";
    license = pkgs.lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "devin";
  };
}
