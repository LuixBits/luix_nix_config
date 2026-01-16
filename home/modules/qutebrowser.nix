{ config, pkgs, ... }:

let
  # Solarized-everything (dark, all sites) bundle plus a local override layer.
  baseCss = ./assets/qutebrowser/solarized-base.css;
  overrideCss = ./assets/qutebrowser/solarized-overrides.css;

  baseCssTarget = "${config.xdg.configHome}/qutebrowser/userstyles/solarized-base.css";
  overrideCssTarget = "${config.xdg.configHome}/qutebrowser/userstyles/solarized-overrides.css";
in {
  home.packages = [ pkgs.qutebrowser ];

  programs.qutebrowser = {
    enable = true;
    settings = {
      content.user_stylesheets = [ baseCssTarget overrideCssTarget ];
    };
  };

  home.file."${baseCssTarget}".source = baseCss;
  home.file."${overrideCssTarget}".source = overrideCss;
}
