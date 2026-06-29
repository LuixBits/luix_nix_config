{ inputs, lib, pkgs, ... }:
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
    inputs.herdr.packages.${pkgs.system}.default
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

  home.file.".codex/config.toml".text = ''
    approval_policy = "on-request"
    sandbox_mode = "workspace-write"
  '';

  home.activation.herdrCodexIntegrationNote = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Herdr/Codex post-install:"
    echo "  herdr integration install codex"
    echo "  herdr integration status"
  '';
}
