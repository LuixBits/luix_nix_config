{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    settings.user = {
      name = "Luix";
      email = "luix@users.noreply.github.com";
    };
  };
  programs.tmux.enable = true;

  home.packages = with pkgs; [
    yazi
  ];
}
