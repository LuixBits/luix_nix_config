{ pkgs ? import <nixpkgs> { } }:
pkgs.symlinkJoin {
  name = "flyff-herdr";
  meta.priority = 4;
  paths = [
    (pkgs.writeShellApplication {
      name = "flyff";
      runtimeInputs = [ pkgs.python3 pkgs.git ];
      text = ''
        export FLYFF_GUIDE_PATH=${./README.md}
        export FLYFF_HERDR_CONFIG=${./config.toml}
        exec python3 ${./workspace.py} "$@"
      '';
    })
    (pkgs.writeShellApplication {
      name = "herdr-flyff";
      text = ''exec flyff attach "$@"'';
    })
    # Retire the old Home Manager-provided launcher immediately without
    # activating Home Manager or replacing its other installed programs.
    (pkgs.writeShellApplication {
      name = "herdr-minipc";
      text = ''
        echo 'The old mini PC session was retired. Opening Flyff.' >&2
        exec herdr-flyff "$@"
      '';
    })
  ];
}
