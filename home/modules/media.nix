{ pkgs, ... }:
{
  home.packages = with pkgs; [
    audacity
    easyeffects
    ffmpeg
    orca-slicer
    yt-dlp
    kdePackages.kdenlive
    shotcut
  ];
}
