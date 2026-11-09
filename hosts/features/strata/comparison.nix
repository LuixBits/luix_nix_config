{
  writeShellApplication,
  python3,
  bubblewrap,
  stdenv,
  lib,
  coreutils,
}:
writeShellApplication {
  name = "strata-compare";
  text = ''
    export STRATA_CXX=${stdenv.cc}/bin/c++
    export STRATA_BWRAP=${bubblewrap}/bin/bwrap
    export STRATA_BUILD_PATH=${
      lib.makeBinPath [
        stdenv.cc
        coreutils
      ]
    }
    exec ${python3}/bin/python3 ${./compare.py} "$@"
  '';
}
