{ pkgs, ... }:
{
  home.packages = with pkgs; [
    audacity
    easyeffects
    ffmpeg
    orca-slicer
    clipgrab
  ];
}
