{ pkgs, ... }:
let
  teamsWeb = pkgs.writeShellScriptBin "teams-web" ''
    exec ${pkgs.google-chrome}/bin/google-chrome-stable \
      --user-data-dir="$HOME/.config/google-chrome-teams" \
      --class=teams-web \
      --name=teams-web \
      --app=https://teams.microsoft.com/v2/ \
      "$@"
  '';
in
{
  home.packages = [
    teamsWeb
    pkgs.google-chrome
  ];

  xdg.desktopEntries.teams-web = {
    name = "Microsoft Teams";
    genericName = "Teams Web";
    comment = "Launch Microsoft Teams in a dedicated Chrome profile";
    exec = "${teamsWeb}/bin/teams-web";
    icon = "google-chrome";
    terminal = false;
    categories = [
      "Network"
      "Office"
    ];
    settings.StartupWMClass = "teams-web";
  };
}
