{ pkgs, ... }:

{
  home.packages = with pkgs; [
    termsonic
    musly
  ];
}
