{ pkgs, ... }:

{
  home.packages = with pkgs; [
    termsonic
    aonsoku
    picard
    chromaprint
    beets
  ];
}

