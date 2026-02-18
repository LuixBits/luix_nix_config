{ pkgs, ... }:
{
  home.packages = with pkgs; [
    playerctl
  ];
}
