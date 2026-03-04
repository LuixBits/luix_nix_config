{ inputs, ... }:
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;
    settings = ./settings.json;
    colors = ./colors.json;
    plugins = ./plugins.json;
    pluginSettings = {
      catwalk = ./plugins/catwalk/settings.json;
      "fancy-audiovisualizer" = ./plugins/fancy-audiovisualizer/settings.json;
      "ip-monitor" = ./plugins/ip-monitor/settings.json;
      "keybind-cheatsheet" = ./plugins/keybind-cheatsheet/settings.json;
      "model-usage" = ./plugins/model-usage/settings.json;
      "privacy-indicator" = ./plugins/privacy-indicator/settings.json;
      todo = ./plugins/todo/settings.json;
    };
  };

  xdg.configFile."noctalia/colorschemes" = {
    source = ./colorschemes;
    recursive = true;
  };
}
