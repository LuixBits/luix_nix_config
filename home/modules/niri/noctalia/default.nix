{ config, inputs, lib, pkgs, hostName ? null, ... }:
let
  wallpaperDir = "/home/luix/Pictures/Wallpapers";
  localPluginSourceDir = "${config.home.homeDirectory}/projects/noctalia-plugins";
  defaultWallpaper = "${wallpaperDir}/autumn-trees-forest-aerial-view-birds-eye-view-green-trees-3840x2160-3153.jpg";
  lockscreenWallpaper = "${wallpaperDir}/gameboy-retro-3840x2160-13655.jpg";

  sharedSettings = {
    bar.default = {
      center = [ "group:g1" "cat" ];
      end = [ "notifications" "volume" "brightness" "battery" "control-center" "session" ];
      font_weight = 700;
      margin_edge = 0;
      margin_ends = 0;
      padding = 12;
      radius = 0;
      scale = 1.15;
      start = [ "launcher" "casio_deck" "wallpaper" "cpu" "temp" "network" "ram" ];
      thickness = 43;
      widget_spacing = 9;

      capsule_group = [
        {
          fill = "surface_variant";
          id = "g1";
          members = [ "clipboard" "clock" ];
          opacity = 1.0;
          padding = 6.0;
        }
      ];
    };

    desktop_widgets.enabled = false;

    idle = {
      behavior_order = [ "lock" "screen-off" "lock-and-suspend" ];

      behavior = {
        lock = {
          action = "lock";
          enabled = true;
          timeout = 600;
        };

        lock-and-suspend = {
          action = "lock_and_suspend";
          enabled = true;
          timeout = 900;
        };

        screen-off = {
          action = "screen_off";
          enabled = false;
          timeout = 660;
        };
      };
    };

    lockscreen = {
      wallpaper = lockscreenWallpaper;
    };

    lockscreen_widgets.enabled = false;

    nightlight.enabled = true;

    osd.position = "top_right";

    plugins = {
      enabled = [ "noctalia/bongocat" "luixbits/casio-deck" ];
      source = [
        {
          auto_update = true;
          kind = "git";
          location = "https://github.com/noctalia-dev/official-plugins";
          name = "official";
        }
        {
          auto_update = true;
          kind = "git";
          location = "https://github.com/noctalia-dev/community-plugins";
          name = "community";
        }
        {
          auto_update = false;
          kind = "path";
          location = localPluginSourceDir;
          name = "local-dev";
        }
      ];
    };

    plugin_settings."luixbits/casio-deck" = {
      watch_model = "casio_abl100we_3565";
      scan_command = "${localPluginSourceDir}/scripts/run-abl100-helper.sh --model abl100we --scan-only --debug";
      helper_command = "${localPluginSourceDir}/scripts/run-abl100-helper.sh --model abl100we --listener --app-info-profile smart-sync --scan-timeout 60 --connect-timeout 25 --app-init-timeout 25 --reconnect-delay 2";
      pair_command = "${localPluginSourceDir}/scripts/run-abl100-helper.sh --model abl100we --setup-pairing --app-info-profile smart-sync --sync-time-on-connect --once --debug --scan-timeout 90 --connect-timeout 25 --app-init-timeout 25";
      monitor_command = "${localPluginSourceDir}/scripts/run-abl100-helper.sh --model abl100we --session-mode fixed --app-info-profile smart-sync --once --debug --scan-timeout 60 --connect-timeout 25 --app-init-timeout 25 --keepalive-interval 10";
      repair_command = "${localPluginSourceDir}/scripts/run-abl100-helper.sh --model abl100we --setup-pairing --repair-pairing --app-info-profile smart-sync --sync-time-on-connect --once --debug --scan-timeout 120 --connect-timeout 25 --app-init-timeout 25";
      saved_watch_address = "FC:51:1B:85:68:53";
      saved_watch_name = "CASIO ABL-100WE";
      autostart_helper = true;
      notify_on_press = false;
      lower_left_preset = "lock";
      lower_right_preset = "teams_accept_audio";
      finder_preset = "teams_toggle_mute";
      timeplace_preset = "none";
      unknown_preset = "none";
    };

    shell = {
      avatar_path = "${wallpaperDir}/mystical-forest-3840x2160-14976.jpg";
      corner_radius_scale = 0.0;
      font_family = "Hurmit Nerd Font Mono";
      polkit_agent = true;
      settings_show_advanced = true;
      ui_scale = 1.35;

      animation.speed = 1.5;

      panel = {
        clipboard_placement = "attached";
        launcher_placement = "attached";
        launcher_session_search = true;
      };

      shadow.alpha = 0.5;
    };

    theme = {
      builtin = "Kanagawa";

      templates = {
        builtin_ids = [ "kitty" ];
        community_ids = [ "neovim" "obsidian" "steam" "yazi" ];
      };
    };

    wallpaper = {
      enabled = true;
      directory = wallpaperDir;
      default.path = defaultWallpaper;
    };

    widget = {
      casio_deck = {
        type = "luixbits/casio-deck:status";
        label = "Casio";
        show_label = true;
        show_press_count = true;
        hide_disconnected = false;
      };

      cat.type = "noctalia/bongocat:cat";
      network.show_label = false;
    };
  };

  perHostSettings = {
    l = {
      dock.monitors = [ "eDP-1" ];

      wallpaper.monitors = {
        "DP-5".path = defaultWallpaper;
        "DP-6".path = defaultWallpaper;
        "eDP-1".path = defaultWallpaper;
      };

      lockscreen_widgets = {
        schema_version = 2;
        widget_order = [
          "lockscreen-login-box@DP-5"
          "lockscreen-login-box@eDP-1"
          "lockscreen-login-box@DP-6"
        ];

        grid = {
          cell_size = 16;
          major_interval = 4;
          visible = true;
        };

        widget = {
          "lockscreen-login-box@DP-5" = {
            box_height = 0.0;
            box_width = 0.0;
            cx = 1720.0;
            cy = 1317.0;
            output = "DP-5";
            rotation = 0.0;
            type = "login_box";

            settings = {
              background_color = "surface_variant";
              background_opacity = 0.88;
              background_radius = 12.0;
              input_opacity = 1.0;
              input_radius = 6.0;
              show_login_button = true;
            };
          };

          "lockscreen-login-box@DP-6" = {
            box_height = 0.0;
            box_width = 0.0;
            cx = 864.0;
            cy = 2949.0;
            output = "DP-6";
            rotation = 0.0;
            type = "login_box";

            settings = {
              background_color = "surface_variant";
              background_opacity = 0.88;
              background_radius = 12.0;
              input_opacity = 1.0;
              input_radius = 6.0;
              show_login_button = true;
            };
          };

          "lockscreen-login-box@eDP-1" = {
            box_height = 0.0;
            box_width = 0.0;
            cx = 823.0;
            cy = 906.0;
            output = "eDP-1";
            rotation = 0.0;
            type = "login_box";

            settings = {
              background_color = "surface_variant";
              background_opacity = 0.88;
              background_radius = 12.0;
              input_opacity = 1.0;
              input_radius = 6.0;
              show_login_button = true;
            };
          };
        };
      };
    };

    pc = {
      dock.monitors = [ "HDMI-A-2" ];
    };

    work = {
      shell.animation.enabled = false;
      shell.shadow.alpha = 0.0;
      dock.monitors = [ "DP-2" "DP-1" "eDP-1" ];
      backdrop.enabled = false;
      desktop_widgets = {
        enabled = true;
        schema_version = 2;
        widget_order = [ "casio_deck_dashboard" ];

        widget.casio_deck_dashboard = {
          type = "luixbits/casio-deck:dashboard";
          output = "DP-1";
          cx = 540.0;
          cy = 360.0;
          box_width = 540.0;
          box_height = 0.0;
          rotation = 0.0;
        };
      };
    };
  };

  hostSettings =
    if hostName != null && builtins.hasAttr hostName perHostSettings then
      perHostSettings.${hostName}
    else
      { };

  noctaliaSettings = lib.recursiveUpdate sharedSettings hostSettings;

  noctaliaIpc = pkgs.writeShellScriptBin "noctalia-ipc" ''
    set -eu

    noctalia=${lib.escapeShellArg (lib.getExe config.programs.noctalia.package)}

    exec "$noctalia" msg "$@"
  '';
in
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia = {
    enable = true;
    settings = noctaliaSettings;
  };

  home.packages = [ noctaliaIpc ];
}
