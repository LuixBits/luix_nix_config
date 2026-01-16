{ config, pkgs, ... }:

let
  # Vaporwave-styled bundle plus a local override layer.
  baseCss = ./assets/qutebrowser/vaporwave-base.css;
  overrideCss = ./assets/qutebrowser/vaporwave-overrides.css;

  baseCssTarget = "${config.xdg.configHome}/qutebrowser/userstyles/vaporwave-base.css";
  overrideCssTarget = "${config.xdg.configHome}/qutebrowser/userstyles/vaporwave-overrides.css";
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
