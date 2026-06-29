{ config, lib, pkgs, ... }:
let
  writeCodexDefaults = pkgs.writeShellScript "write-codex-defaults" ''
    set -eu

    config_file="$1"
    tmp_file="$config_file.tmp.$$"
    trap 'rm -f "$tmp_file"' EXIT

    ${pkgs.gawk}/bin/awk '
      BEGIN {
        print "approval_policy = \"on-request\""
        print "sandbox_mode = \"workspace-write\""
      }
      /^[[:space:]]*\[/ { in_table = 1 }
      !in_table && /^[[:space:]]*(approval_policy|sandbox_mode)[[:space:]]*=/ { next }
      NR == 1 && $0 != "" { print "" }
      { print }
    ' "$config_file" > "$tmp_file"

    ${pkgs.coreutils}/bin/mv "$tmp_file" "$config_file"
    ${pkgs.coreutils}/bin/chmod 0600 "$config_file"
    trap - EXIT
  '';
in
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    profiles.default.userSettings = {
      "terminal.integrated.defaultProfile.linux" = "fish";
      "terminal.integrated.profiles.linux".fish.path = "${pkgs.fish}/bin/fish";
    };
  };

  home.packages = with pkgs; [
    bubblewrap
    codex
    dbeaver-bin
    gcc
    gnumake
    jdk
    lua
    lua51Packages.lz-n
    luarocks-nix
    nodejs
    pnpm
    (php83.buildEnv {
      extraConfig = ''
        memory_limit = 4G
        upload_max_filesize = 500M
        post_max_size = 500M
      '';
    })
    python3
    whois
    dig
    nmap
  ];

  home.activation.ensureCodexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    codex_dir="${config.home.homeDirectory}/.codex"
    config_file="$codex_dir/config.toml"

    run mkdir -p "$codex_dir"

    if [ -L "$config_file" ]; then
      link_target="$(readlink "$config_file")"
      mutable_copy="$config_file.hm-mutable"
      run cp -f "$link_target" "$mutable_copy"
      run rm -f "$config_file"
      run mv -f "$mutable_copy" "$config_file"
    fi

    if [ ! -e "$config_file" ]; then
      run install -m 0600 /dev/null "$config_file"
    fi

    run ${writeCodexDefaults} "$config_file"
  '';
}
