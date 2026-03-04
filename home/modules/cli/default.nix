{ pkgs, lib, ... }:
{
  programs.git = {
    enable = true;
    settings.user = {
      name = lib.mkDefault "Luix";
      email = lib.mkDefault "luix@users.noreply.github.com";
    };
  };
  programs.tmux.enable = true;

  home.packages = with pkgs; [
    yazi
  ];
}
