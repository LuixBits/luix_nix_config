{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  stdenv,
  python3,
}:
let
  version = "0.2.10";
  engineVersion = "0.1.56";
  python = python3.withPackages (
    p: with p; [
      numpy
      jinja2
      regex
      pyyaml
      tqdm
      requests
      pillow
      psutil
      truststore
      textual
    ]
  );
  engine = stdenvNoCC.mkDerivation {
    pname = "strata-engine-rx7900";
    version = engineVersion;
    src = fetchurl {
      url = "https://github.com/Niko1221/Strata/releases/download/v${version}/strata-engine-${engineVersion}-linux-x86_64-hip-rx7900.tar.gz";
      sha256 = "b57768c85db8aa47f6bd62352df561f22504420a9629c49a573749a9555c6b1d";
    };
    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib ];
    dontUnpack = true;
    dontStrip = true;
    installPhase = ''
      mkdir -p "$out/libexec/strata"
      tar -xzf "$src" -C "$out/libexec/strata"
    '';
    meta = {
      description = "Strata HIP engine and bundled ROCm runtime for gfx1100/1101/1102";
      license = lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
    };
  };
in
stdenvNoCC.mkDerivation {
  pname = "strata";
  inherit version;
  src = fetchurl {
    url = "https://github.com/Niko1221/Strata/archive/refs/tags/v${version}.tar.gz";
    sha256 = "bf69dfb868c0e31d9079289543bf62cc7e1cdfde8b1468f98250ba28b41c46f3";
  };
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/strata" "$out/bin"
    cp -r . "$out/lib/strata/"
    makeWrapper ${python}/bin/python3 "$out/bin/strata" \
      --add-flags "$out/lib/strata/strata.py" \
      --set STRATA_NO_HANDOVER 1 --set STRATA_NO_ACQUIRE 1
    makeWrapper ${python}/bin/python3 "$out/bin/strata-server" \
      --add-flags "$out/lib/strata/serve/server.py" \
      --set STRATA_NO_HANDOVER 1 --set STRATA_NO_ACQUIRE 1
    makeWrapper ${python}/bin/python3 "$out/bin/strata-pack" \
      --add-flags "$out/lib/strata/tools/iq_pack.py"
    makeWrapper ${engine}/libexec/strata/strata "$out/bin/strata-engine" \
      --prefix LD_LIBRARY_PATH : ${engine}/libexec/strata
    runHook postInstall
  '';
  passthru = {
    inherit engine engineVersion python;
    enginePath = "${engine}/libexec/strata/strata";
  };
  meta = {
    description = "Pinned Strata terminal and inference server with the RX 7900 HIP engine";
    homepage = "https://github.com/Niko1221/Strata";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "strata";
  };
}
