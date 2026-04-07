{ pkgs, ... }:
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
      core.fileMode = false;
      credential.helper = "cache";
    };
  };

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
    teams-for-linux
    vivaldi
    vim
  ];
}
