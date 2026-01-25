{ pkgs, ... }:
{
  home.packages = with pkgs; [
    wl-clipboard
    cliphist
    wl-clip-persist
  ];
}
