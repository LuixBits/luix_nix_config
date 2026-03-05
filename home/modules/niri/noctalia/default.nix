{ inputs, pkgs, hostName ? null, ... }:
let
  baseSettings = builtins.fromJSON (builtins.readFile ./settings.json);
  basePlugins = builtins.fromJSON (builtins.readFile ./plugins.json);
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
      setWallpaperOnAllMonitors = true;
      enableMultiMonitorDirectories = false;
    };
  };
  pcSettings = baseSettings // {
    bar = baseSettings.bar // {
      monitors = [ "HDMI-A-2" "HDMI-A-3" ];
    };
    dock = baseSettings.dock // {
      monitors = [ "HDMI-A-2" ];
    };
    desktopWidgets = baseSettings.desktopWidgets // {
      monitorWidgets = [ ];
    };
    general = baseSettings.general // {
      avatarImage = "/home/luix/.face";
    };
    wallpaper = baseSettings.wallpaper // {
      directory = "/home/luix/Pictures/Wallpapers";
    };
  };
  workDisabledPlugins = [
    "catwalk"
    "fancy-audiovisualizer"
    "github-feed"
    "ip-monitor"
    "keybind-cheatsheet"
    "mini-docker"
    "model-usage"
    "todo"
  ];
  workPluginStates = builtins.mapAttrs (
    name: value:
    if builtins.elem name workDisabledPlugins then
      value // { enabled = false; }
    else
      value
  ) basePlugins.states;
  workPlugins = basePlugins // {
    states = workPluginStates;
  };
  workSettings = baseSettings // {
    # Keep work shell lightweight when driving DisplayLink outputs.
    bar = baseSettings.bar // {
      monitors = [ "DVI-I-1" ];
      widgets = baseSettings.bar.widgets // {
        left = builtins.filter (
          widget:
          !(builtins.elem (widget.id or "") [ "AudioVisualizer" "plugin:ip-monitor" "plugin:model-usage" ])
        ) baseSettings.bar.widgets.left;
        center = [ ];
      };
    };
    dock = baseSettings.dock // {
      monitors = [ "DVI-I-1" ];
    };
    desktopWidgets = baseSettings.desktopWidgets // {
      monitorWidgets = [ ];
    };
    general = baseSettings.general // {
      animationDisabled = true;
      enableShadows = false;
      showScreenCorners = false;
      showChangelogOnStartup = false;
    };
    ui = baseSettings.ui // {
      boxBorderEnabled = false;
      panelBackgroundOpacity = 1.0;
      tooltipsEnabled = false;
    };
    wallpaper = baseSettings.wallpaper // {
      overviewBlur = 0;
      overviewTint = 0;
    };
  };
  settingsFile =
    if hostName == "l" then
      pkgs.writeText "noctalia-settings-l.json" (builtins.toJSON lSettings)
    else if hostName == "pc" then
      pkgs.writeText "noctalia-settings-pc.json" (builtins.toJSON pcSettings)
    else if hostName == "work" then
      pkgs.writeText "noctalia-settings-work.json" (builtins.toJSON workSettings)
    else
      ./settings.json;
  pluginsFile =
    if hostName == "work" then
      pkgs.writeText "noctalia-plugins-work.json" (builtins.toJSON workPlugins)
    else
      ./plugins.json;
  pluginEntries = builtins.readDir ./plugins;
  pluginSettings = builtins.listToAttrs (
    builtins.filter (entry: entry != null) (
      map
        (
          pluginName:
          if pluginEntries.${pluginName} == "directory" && builtins.pathExists (./plugins + "/${pluginName}/settings.json") then
            {
              name = pluginName;
              value = ./plugins + "/${pluginName}/settings.json";
            }
          else
            null
        )
        (builtins.attrNames pluginEntries)
    )
  );
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
    plugins = pluginsFile;
    pluginSettings = pluginSettings;
  };

  xdg.configFile."noctalia/colorschemes" = {
    source = ./colorschemes;
    recursive = true;
  };
}
