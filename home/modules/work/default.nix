{ config, pkgs, ... }:
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user = {
        name = "Luiz Perren";
        email = "dummy@example.invalid";
      };
      init.defaultBranch = "main";
      pull.rebase = false;
      color.ui = "auto";
      core.editor = "vim";
      credential.helper = "cache";
    };
  };

  home.sessionPath = [
    "/home/luiz/siga/roiguard/bin"
    "/home/luiz/siga/webshop/src/html/bin"
    "/home/luiz/siga/bincommands/bin"
  ];

  xdg.configFile."fish/completions/siga.fish".source =
    config.lib.file.mkOutOfStoreSymlink "/home/luiz/siga/bincommands/completions/siga.fish";

  home.packages = with pkgs; [
    azure-cli
    brave
    deckmaster
    go
    htop
    jq
    kubectl
    kubelogin
    openssl
    php83Packages.composer
    spotify
    vivaldi
    vim
    filezilla
  ];
}
