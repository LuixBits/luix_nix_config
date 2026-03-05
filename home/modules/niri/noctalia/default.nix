{ inputs, pkgs, hostName ? null, ... }:
let
  baseSettings = builtins.fromJSON (builtins.readFile ./settings.json);
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
  workSettings = baseSettings // {
    # Keep work panels on both external monitors so the portrait screen
    # remains fully usable regardless of connector reorder.
    bar = baseSettings.bar // {
      monitors = [ "DVI-I-1" "DVI-I-2" ];
    };
    dock = baseSettings.dock // {
      monitors = [ "DVI-I-1" ];
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
    plugins = ./plugins.json;
    pluginSettings = pluginSettings;
  };

  xdg.configFile."noctalia/colorschemes" = {
    source = ./colorschemes;
    recursive = true;
  };
}
