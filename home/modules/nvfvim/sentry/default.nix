{
  inputs,
  ...
}: {
  imports = [
    inputs.luixbits-sentry.homeManagerModules.nvf
  ];

  programs.nvf = {
    sentry = {
      enable = true;
      setupOpts = import ./settings.nix;
    };

    settings.vim = {
      keymaps = import ./keymaps.nix;
      binds.whichKey.register."<leader>s" = "+Sentry";
    };
  };
}
