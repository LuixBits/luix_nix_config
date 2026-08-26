{
  config,
  lib,
  pkgs,
  ...
}:
let
  codexVersion = "0.149.0";
  codexPackage = pkgs.stdenvNoCC.mkDerivation {
    pname = "codex";
    version = codexVersion;

    src = pkgs.fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-package-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-HAi6Jiggt41J6nqT8ya2tDC3Ll/kaDDkM+3vEuUSMkQ=";
    };

    sourceRoot = ".";
    dontStrip = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out"
      cp -R bin codex-path codex-resources codex-package.json "$out/"

      runHook postInstall
    '';

    meta = {
      description = "OpenAI Codex CLI official release bundle";
      homepage = "https://github.com/openai/codex";
      license = lib.licenses.asl20;
      mainProgram = "codex";
      platforms = [ "x86_64-linux" ];
    };
  };
  # Preserve the historical command while both names use the same current,
  # declaratively pinned release.
  codexNew = pkgs.writeShellScriptBin "codex-new" ''
    exec ${codexPackage}/bin/codex "$@"
  '';
  writeCodexDefaults = pkgs.writeShellScript "write-codex-defaults" ''
    set -eu

    config_file="$1"
    tmp_file="$config_file.tmp.$$"
    trap 'rm -f "$tmp_file"' EXIT

    ${pkgs.gawk}/bin/awk '
      BEGIN {
        print "approval_policy = \"on-request\""
        print "sandbox_mode = \"workspace-write\""
        print "model = \"gpt-5.6-sol\""
        print "model_reasoning_effort = \"xhigh\""
        print "personality = \"pragmatic\""
      }
      /^[[:space:]]*\[/ { in_table = 1 }
      !in_table && /^[[:space:]]*(approval_policy|sandbox_mode|model|model_reasoning_effort|personality)[[:space:]]*=/ { next }
      NR == 1 && $0 != "" { print "" }
      { print }
    ' "$config_file" > "$tmp_file"

    ${pkgs.coreutils}/bin/mv "$tmp_file" "$config_file"
    ${pkgs.coreutils}/bin/chmod 0600 "$config_file"
    trap - EXIT
  '';
in
{
  imports = [
    ../graphify
    ../kimi-code
    ../sentry-cli
  ];

  programs.graphify.enable = true;
  programs.kimiCode.enable = true;
  programs.sentryCli.enable = true;

  programs.codex = {
    enable = true;
    package = codexPackage;
  };

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
    codexNew
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
