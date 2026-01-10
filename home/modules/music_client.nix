{ pkgs, ... }:

let
  musicSync = pkgs.writeShellScriptBin "music-sync" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    # Do NOT run as root; sudo makes ssh use /root/.ssh (different keys) and typically fails. :contentReference[oaicite:0]{index=0}
    if [[ "''${EUID:-$(id -u)}" -eq 0 ]]; then
      echo "ERROR: Do not run music-sync with sudo. Run as your user: music-sync" >&2
      exit 1
    fi

    SRC="''${MUSIC_SRC:-/home/luix/Documents/sorted_music/}"
    DEST_USER="''${MUSIC_DEST_USER:-luixmusic}"
    DEST_HOST="''${MUSIC_DEST_HOST:-192.168.0.33}"
    DEST_DIR="''${MUSIC_DEST_DIR:-/srv/music/}"

    if [[ ! -d "$SRC" ]]; then
      echo "ERROR: Source folder does not exist: $SRC" >&2
      exit 1
    fi

    # Ensure destination exists and is writable (may prompt for server sudo password).
    ${pkgs.openssh}/bin/ssh -tt "''${DEST_USER}@''${DEST_HOST}" \
      "sudo mkdir -p '\"''${DEST_DIR}\"' && sudo chown -R '\"''${DEST_USER}:navidrome\"' '\"''${DEST_DIR}\"' && sudo chmod 0750 '\"''${DEST_DIR}\"'"

    RSYNC_FLAGS=(-avh --info=progress2)

    # Optional modes:
    #   MUSIC_DRYRUN=1  -> preview only
    #   MUSIC_MIRROR=1  -> mirror (deletes on server what no longer exists locally)
    if [[ "''${MUSIC_DRYRUN:-0}" == "1" ]]; then
      RSYNC_FLAGS+=(-n --itemize-changes)
    fi
    if [[ "''${MUSIC_MIRROR:-0}" == "1" ]]; then
      RSYNC_FLAGS+=(--delete)
    fi

    # Trailing slash on SRC means “copy contents of directory”, not the directory itself. :contentReference[oaicite:1]{index=1}
    ${pkgs.rsync}/bin/rsync "''${RSYNC_FLAGS[@]}" \
      "''${SRC}" \
      "''${DEST_USER}@''${DEST_HOST}:''${DEST_DIR}"
  '';
in
{
  # Home Manager installs user-scoped packages via home.packages. :contentReference[oaicite:2]{index=2}
  home.packages = with pkgs; [
    termsonic
    aonsoku
    picard
    chromaprint
    beets

    openssh
    rsync
    musicSync  # provides `music-sync` :contentReference[oaicite:3]{index=3}
  ];
}

