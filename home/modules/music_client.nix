{ pkgs, ... }:

let
  musicServerInit = pkgs.writeShellScriptBin "music-server-init" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    if [[ "''${EUID:-$(id -u)}" -eq 0 ]]; then
      echo "ERROR: do not run with sudo. Run: music-server-init" >&2
      exit 1
    fi

    DEST_USER="''${MUSIC_DEST_USER:-luixmusic}"
    DEST_HOST="''${MUSIC_DEST_HOST:-192.168.0.33}"
    DEST_DIR="''${MUSIC_DEST_DIR:-/srv/music}"

    ${pkgs.openssh}/bin/ssh -tt "''${DEST_USER}@''${DEST_HOST}" \
      "sudo mkdir -p '\"''${DEST_DIR}\"' && sudo chown -R ''${DEST_USER}:navidrome '\"''${DEST_DIR}\"' && sudo chmod 0750 '\"''${DEST_DIR}\"'"
  '';

  musicSync = pkgs.writeShellScriptBin "music-sync" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    if [[ "''${EUID:-$(id -u)}" -eq 0 ]]; then
      echo "ERROR: do not run with sudo. Run: music-sync" >&2
      exit 1
    fi

    SRC="''${MUSIC_SRC:-/home/luix/Documents/sorted_music/}"
    DEST_USER="''${MUSIC_DEST_USER:-luixmusic}"
    DEST_HOST="''${MUSIC_DEST_HOST:-192.168.0.33}"
    DEST_DIR="''${MUSIC_DEST_DIR:-/srv/music/}"

    if [[ ! -d "''${SRC}" ]]; then
      echo "ERROR: source folder not found: ''${SRC}" >&2
      exit 1
    fi

    RSYNC_FLAGS=(-avh --info=progress2)

    # Optional:
    #   MUSIC_DRYRUN=1  -> preview changes only
    #   MUSIC_MIRROR=1  -> mirror (deletes on server what no longer exists locally)
    if [[ "''${MUSIC_DRYRUN:-0}" == "1" ]]; then
      RSYNC_FLAGS+=(-n --itemize-changes)
    fi
    if [[ "''${MUSIC_MIRROR:-0}" == "1" ]]; then
      RSYNC_FLAGS+=(--delete)
    fi

    ${pkgs.rsync}/bin/rsync "''${RSYNC_FLAGS[@]}" \
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

    openssh
    rsync
    musicServerInit
    musicSync
  ];
}

