{ pkgs, ... }:
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";

    fcitx5 = {
      addons = with pkgs; [
        fcitx5-mozc
      ];

      # Keep the Fcitx GTK and Qt modules enabled for broad application
      # compatibility under Niri.
      waylandFrontend = false;

      settings = {
        globalOptions = {
          Behavior.ActiveByDefault = false;

          # Mod+Space opens Noctalia and Ctrl+Space opens Neovim completion.
          "Hotkey/TriggerKeys"."0" = "Control+Alt+space";
        };

        inputMethod = {
          GroupOrder."0" = "Default";

          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "ch";
            DefaultIM = "mozc";
          };

          "Groups/0/Items/0".Name = "keyboard-ch";
          "Groups/0/Items/1" = {
            Name = "mozc";
            Layout = "ch";
          };
        };
      };
    };
  };

  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
  ];
}
