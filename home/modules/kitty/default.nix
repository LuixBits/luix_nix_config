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

      url_color = "#8ea4a2";
      url_style = "curly";
      detect_urls = "yes";
      show_hyperlink_targets = "yes";
      underline_hyperlinks = "always";

      strip_trailing_spaces = "always";

      shell = "/run/current-system/sw/bin/fish";

      enable_audio_bell = "yes";
      visual_bell_duration = "0.0";
      window_alert_on_bell = "yes";
      bell_on_tab = "kanagawa ";

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
      ## name: Kanagawa Dragon
      ## author: Noctalia community palette, adapted by Luix
      ## license: MIT
      ## blurb: Dark, mossy Kanagawa palette matched to Noctalia.

      #: The basic colors

      foreground                      #c5c9c5
      background                      #181616
      selection_foreground            #181616
      selection_background            #c5c9c5


      #: Text opacity on inactive kitty windows (0.0 to 1.0)

      inactive_text_alpha 0.5


      #: Cursor colors

      cursor                          #c5c9c5
      cursor_text_color               background


      #: URL underline color when hovering with mouse

      url_color                       #8ea4a2


      #: kitty window border colors and terminal bell colors

      active_border_color             #8a9a7b
      inactive_border_color           #282727
      bell_border_color               #c4b28a
      visual_bell_color               none


      #: OS Window titlebar colors

      wayland_titlebar_color          system
      macos_titlebar_color            system


      #: Tab bar colors

      active_tab_foreground           #181616
      active_tab_background           #8a9a7b
      inactive_tab_foreground         #c8c093
      inactive_tab_background         #282727
      tab_bar_background              #181616
      tab_bar_margin_color            none
      tab_separator                   " ┆ "


      #: Colors for marks (marked text in the terminal)

      mark1_foreground                #181616
      mark1_background                #8a9a7b
      mark2_foreground                #181616
      mark2_background                #c4b28a
      mark3_foreground                #181616
      mark3_background                #8ea4a2


      #: The basic 16 colors

      #: black
      color0                          #282727
      color8                          #625e5a

      #: red
      color1                          #c4746e
      color9                          #c4746e

      #: green
      color2                          #8a9a7b
      color10                         #8a9a7b

      #: yellow
      color3                          #c4b28a
      color11                         #b6927b

      #: blue
      color4                          #8ba4b0
      color12                         #8ba4b0

      #: magenta
      color5                          #a292a3
      color13                         #a292a3

      #: cyan
      color6                          #8ea4a2
      color14                         #8ea4a2

      #: white
      color7                          #c5c9c5
      color15                         #c8c093
    '';
  };
}
