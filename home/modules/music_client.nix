{ pkgs, ... }:

{
  home.packages = with pkgs; [
    termsonic
    aonsoku
  ];
}
