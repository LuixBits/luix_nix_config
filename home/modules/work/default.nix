# User tools and preferences required by the work environment.
{ config, pkgs, ... }:
{
  imports = [
    ../teams
  ];

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user = {
        name = "Luiz Perren";
        email = "luiz.perren@siga.swiss";
      };
      init.defaultBranch = "main";
      pull.rebase = false;
      color.ui = "auto";
      core.editor = "vim";
      credential.helper = "cache";
    };
  };

  programs.java = {
    enable = true;
    package = pkgs.jdk;
  };

  programs.fish.shellAliases = {
    pia = "pia-setup --connect";
    piaoff = "pia-setup --disconnect";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/siga/roiguard/bin"
    "${config.home.homeDirectory}/siga/webshop/src/html/bin"
    "${config.home.homeDirectory}/siga/bincommands/bin"
  ];

  # Azure CLI/Python requests must use the system bundle, which includes the
  # SIGA Gateway CA alongside the normal public certificate authorities.
  home.sessionVariables.REQUESTS_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt";

  # The paired system work module imports the company CA from a local file.
  # Plain rebuild-helper invocations must allow that read automatically.
  programs.buildandpush.impure = true;

  xdg.configFile."fish/completions/siga.fish".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/siga/bincommands/completions/siga.fish";

  home.packages = with pkgs; [
    azure-cli
    brave
    cloudflare-warp
    deckmaster
    filezilla
    go
    htop
    jq
    kubectl
    kubelogin
    mysql84
    openssl
    php83Packages.composer
    spotify
    vivaldi
    vim
  ];
}
