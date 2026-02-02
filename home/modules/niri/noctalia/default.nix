{ inputs, pkgs, ... }:

{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  home.packages = [
    inputs.noctalia-unofficial-auth-agent.packages.${pkgs.system}.noctalia-polkit
  ];

  systemd.user.services.noctalia-polkit = {
    Unit = {
      Description = "Noctalia Polkit Authentication Agent";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${inputs.noctalia-unofficial-auth-agent.packages.${pkgs.system}.noctalia-polkit}/bin/noctalia-polkit";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;
    plugins = {
      sources = [
        {
          enabled = true;
          name = "Official Noctalia Plugins";
          url = "https://github.com/noctalia-dev/noctalia-plugins";
        }
        {
          enabled = true;
          name = "Anthonyhab plugins";
          url = "https://github.com/anthonyhab/noctalia-plugins";
        }
      ];

      states = {
        "polkit-auth" = {
          enabled = true;
          sourceUrl = "https://github.com/anthonyhab/noctalia-plugins";
        };
      };

      version = 1;
    };
  };
}
