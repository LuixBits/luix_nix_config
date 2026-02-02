{ pkgs, ... }:
{
  home.packages = with pkgs; [
    xwayland-run
  ];
}
