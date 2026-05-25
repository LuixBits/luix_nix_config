{
  config,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.nix-doom-emacs-unstraightened.homeModule
  ];

  programs.fd.enable = true;
  programs.ripgrep.enable = true;

  programs.doom-emacs = {
    enable = true;
    provideEmacs = true;
    doomDir = ./doom.d;
    emacs = pkgs.emacs-pgtk;

    # Avoids some Git revision lookup issues with newer Nix versions.
    experimentalFetchTree = true;
  };
}
