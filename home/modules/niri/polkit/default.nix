{ pkgs, ... }:
{
  home.packages = [
    pkgs.kdePackages.polkit-kde-agent-1
  ];

  systemd.user.services.polkit-kde-agent = {
    Unit = {
      Description = "KDE Polkit Authentication Agent";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
