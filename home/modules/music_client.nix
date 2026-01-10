{ pkgs, ... }:

let
  musicSync = pkgs.writeShellScriptBin "music-sync" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    SRC="''${MUSIC_SRC:-/home/luix/Documents/sorted_music/}"
    DEST_USER="''${MUSIC_DEST_USER:-luixmusic}"
    DEST_HOST="''${MUSIC_DEST_HOST:-192.168.0.33}"
    DEST_DIR="''${MUSIC_DEST_DIR:-/srv/music/}"

    ${pkgs.openssh}/bin/ssh "''${DEST_USER}@''${DEST_HOST}" \
      "sudo mkdir -p ''${DEST_DIR} && sudo chown -R ''${DEST_USER}:navidrome ''${DEST_DIR}"

    ${pkgs.rsync}/bin/rsync -avh --info=progress2 \
      "''${SRC}" \
      "''${DEST_USER}@''${DEST_HOST}:''${DEST_DIR}"
  '';
in
{
  home.packages = with pkgs; [
    termsonic
    aonsoku
    picard
    chromaprint
    beets
    musicSync
  ];
}

