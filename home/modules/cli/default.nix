{ pkgs, lib, ... }:
{
  programs.git = {
    enable = true;
    settings = {
      core.filemode = false;
      user = {
        name = lib.mkDefault "LuixBits";
        email = lib.mkDefault "10044859+LuixBits@users.noreply.github.com";
      };
    };
  };
  programs.tmux.enable = true;

  home.packages = with pkgs; [
    ffmpeg
    gh
    gifski
    slurp
    wf-recorder
    yazi
  ];
}
