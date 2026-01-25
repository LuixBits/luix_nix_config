{ pkgs, ... }:
{
  home.packages = with pkgs; [
    swayidle
    swaylock
    wlogout
  ];
}
