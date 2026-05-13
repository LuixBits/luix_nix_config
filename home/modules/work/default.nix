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
      credential.helper = "cache";
    };
  };

  home.packages = with pkgs; [
    (writeShellScriptBin "teams-web" ''
      exec ${google-chrome}/bin/google-chrome-stable \
        --user-data-dir="$HOME/.config/google-chrome-teams" \
        --class=teams-web \
        --name=teams-web \
        --app=https://teams.microsoft.com/v2/ \
        "$@"
    '')
    azure-cli
    brave
    deckmaster
    go
    google-chrome
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

  xdg.desktopEntries.teams-web = {
    name = "Microsoft Teams";
    genericName = "Teams Web";
    comment = "Launch Microsoft Teams in a dedicated Chrome profile";
    exec = "teams-web";
    icon = "google-chrome";
    terminal = false;
    categories = [ "Network" "Office" ];
    settings.StartupWMClass = "teams-web";
  };
}
