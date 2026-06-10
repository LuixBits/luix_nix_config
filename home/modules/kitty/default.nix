{ ... }:
let
  kanagawa = import ../theme/kanagawa.nix;
  c = kanagawa.palette;
in
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

      url_color = c.springBlue;
      url_style = "curly";
      detect_urls = "yes";
      show_hyperlink_targets = "yes";
      underline_hyperlinks = "always";

      strip_trailing_spaces = "always";

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
      ## name: Kanagawa
      ## upstream: https://github.com/rebelot/kanagawa.nvim/

      foreground                      ${c.fujiWhite}
      background                      ${c.sumiInk3}
      selection_foreground            ${c.oldWhite}
      selection_background            ${c.waveBlue2}

      inactive_text_alpha             0.5

      cursor                          ${c.oldWhite}
      cursor_text_color               background

      url_color                       ${c.springBlue}

      active_border_color             ${c.springBlue}
      inactive_border_color           ${c.sumiInk4}
      bell_border_color               ${c.surimiOrange}
      visual_bell_color               none

      wayland_titlebar_color          system
      macos_titlebar_color            system

      active_tab_foreground           ${c.oldWhite}
      active_tab_background           ${c.sumiInk3}
      inactive_tab_foreground         ${c.fujiGray}
      inactive_tab_background         ${c.sumiInk3}
      tab_bar_background              ${c.sumiInk0}
      tab_bar_margin_color            none
      tab_separator                   " | "

      mark1_foreground                ${c.sumiInk3}
      mark1_background                ${c.springBlue}
      mark2_foreground                ${c.sumiInk3}
      mark2_background                ${c.springGreen}
      mark3_foreground                ${c.sumiInk3}
      mark3_background                ${c.surimiOrange}

      color0                          ${c.sumiInk0}
      color8                          ${c.fujiGray}

      color1                          ${c.autumnRed}
      color9                          ${c.samuraiRed}

      color2                          ${c.autumnGreen}
      color10                         ${c.springGreen}

      color3                          ${c.boatYellow2}
      color11                         ${c.carpYellow}

      color4                          ${c.crystalBlue}
      color12                         ${c.springBlue}

      color5                          ${c.oniViolet}
      color13                         ${c.springViolet1}

      color6                          ${c.waveAqua1}
      color14                         ${c.waveAqua2}

      color7                          ${c.oldWhite}
      color15                         ${c.fujiWhite}

      color16                         ${c.surimiOrange}
      color17                         ${c.peachRed}
    '';
  };
}
