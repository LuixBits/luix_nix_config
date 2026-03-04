{ inputs, pkgs, hostName ? null, ... }:
let
  baseSettings = builtins.fromJSON (builtins.readFile ./settings.json);
  workVerticalWidgets =
    let
      matching = builtins.filter (entry: entry.name == "DVI-I-2") baseSettings.desktopWidgets.monitorWidgets;
    in
    if matching == [ ] then [ ] else (builtins.head matching).widgets;
  lSettings = baseSettings // {
    bar = baseSettings.bar // {
      monitors = [ "eDP-1" ];
    };
    dock = baseSettings.dock // {
      monitors = [ "eDP-1" ];
    };
    desktopWidgets = baseSettings.desktopWidgets // {
      monitorWidgets = [
        {
          name = "eDP-1";
          widgets = [ ];
        }
      ];
    };
    general = baseSettings.general // {
      avatarImage = "/home/luix/.face";
    };
    wallpaper = baseSettings.wallpaper // {
      directory = "/home/luix/Pictures/Wallpapers";
    };
  };
  pcSettings = baseSettings // {
    bar = baseSettings.bar // {
      monitors = [ "HDMI-A-2" ];
    };
    dock = baseSettings.dock // {
      monitors = [ "HDMI-A-2" ];
    };
    desktopWidgets = baseSettings.desktopWidgets // {
      monitorWidgets = [
        {
          name = "HDMI-A-3";
          widgets = workVerticalWidgets;
        }
      ];
    };
    general = baseSettings.general // {
      avatarImage = "/home/luix/.face";
    };
    wallpaper = baseSettings.wallpaper // {
      directory = "/home/luix/Pictures/Wallpapers";
    };
  };
  settingsFile =
    if hostName == "l" then
      pkgs.writeText "noctalia-settings-l.json" (builtins.toJSON lSettings)
    else if hostName == "pc" then
      pkgs.writeText "noctalia-settings-pc.json" (builtins.toJSON pcSettings)
    else
      ./settings.json;
in
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;
    settings = settingsFile;
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
