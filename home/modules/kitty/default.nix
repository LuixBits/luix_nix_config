{ ... }:
{
  programs.kitty = {
    enable = true;
    font = {
      name = "Hurmit Nerd Font Mono";
      size = 30;
    };
    settings = {
      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";

      symbol_map = "U+E0A0-U+E0A3,U+E0C0-U+E0C7 PowerlineSymbols";
      text_composition_strategy = "platform";

      cursor_trail = "1";
      cursor_trail_decay = "0.15 0.3";
      cursor_trail_start_threshold = "2";
      mouse_hide_wait = "2.0";

      url_color = "#0087bd";
      url_style = "curly";
      detect_urls = "yes";
      show_hyperlink_targets = "yes";
      underline_hyperlinks = "always";

      strip_trailing_spaces = "always";

      shell = "/run/current-system/sw/bin/fish";

      enable_audio_bell = "yes";
      visual_bell_duration = "0.0";
      window_alert_on_bell = "yes";
      bell_on_tab = "🔔 ";

      remember_window_size = "yes";
      remember_window_position = "no";
      window_border_width = "5pt";
      draw_minimal_borders = "yes";
      window_margin_width = "0";
      single_window_margin_width = "1";
      window_padding_width = "1";
      single_window_padding_width = "1";
      placement_strategy = "center";
      inactive_text_alpha = "0.5";
      tab_bar_style = "fade";
      tab_bar_align = "center";
      tab_fade = "0.15 0.35 0.65 1";

      background_blur = "4";
      background_opacity = "0.99";

      clipboard_control = "write-clipboard write-primary read-clipboard-ask read-primary-ask";
      allow_hyperlinks = "yes";
      shell_integration = "enabled";
      allow_cloning = "ask";
      notify_on_cmd_finish = "unfocused 10.0 bell";
    };
    extraConfig = ''
      ## name: VividPunk
      ## author: CarleScript
      ## license: MIT
      ## blurb: Vivid theme based on the colors of my wallpaper created by 00xBAD (https://wallhaven.cc/w/gpy1k3)

      #: The basic colors

      foreground                      #F88132
      background                      #171A26
      selection_foreground            #171A26
      selection_background            #F88132


      #: Text opacity on inactive kitty windows (0.0 to 1.0)

      inactive_text_alpha 0.5


      #: Cursor colors

      cursor                          #F88132
      cursor_text_color               background


      #: URL underline color when hovering with mouse

      url_color                       #F88132


      #: kitty window border colors and terminal bell colors

      active_border_color             #F88132
      inactive_border_color           #171A26
      bell_border_color               #F88132
      visual_bell_color               none


      #: OS Window titlebar colors

      wayland_titlebar_color          system
      macos_titlebar_color            system


      #: Tab bar colors

      active_tab_foreground           #171A26
      active_tab_background           #F88132
      inactive_tab_foreground         #F88132
      inactive_tab_background         #171A26
      tab_bar_background              #171A26
      tab_bar_margin_color            none
      tab_separator                   " | "


      #: Colors for marks (marked text in the terminal)

      mark1_foreground                #171A26
      mark1_background                #F88132
      mark2_foreground                #171A26
      mark2_background                #F88132
      mark3_foreground                #171A26
      mark3_background                #F88132


      #: The basic 16 colors

      #: black
      color0                          #010101
      color8                          #757575

      #: red
      color1                          #A32522
      color9                          #D53B3E

      #: green
      color2                          #115A24
      color10                         #0A8439

      #: yellow
      color3                          #D5A243
      color11                         #F5BF59

      #: blue
      color4                          #263788
      color12                         #6C85E8

      #: magenta
      color5                          #793664
      color13                         #B75492

      #: cyan
      color6                          #128CA1
      color14                         #7ACCD4

      #: white
      color7                          #DADAD7
      color15                         #F3F3F2
    '';
  };
}
