{
  inputs,
  ...
}:
{
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

      # Dedicated Sentry buffers follow the same lifecycle as the other tool
      # views: q closes the focused view. The prefixed close action remains
      # available for discoverability through WhichKey.
      luaConfigRC.sentry-window-keymaps = ''
        local sentry_windows = vim.api.nvim_create_augroup("LuixSentryWindows", { clear = true })
        vim.api.nvim_create_autocmd("FileType", {
          group = sentry_windows,
          pattern = "sentry",
          callback = function(args)
            vim.keymap.set("n", "q", function()
              pcall(vim.cmd.close)
            end, {
              buffer = args.buf,
              desc = "Close Sentry view",
              silent = true,
            })
          end,
        })
      '';
    };
  };
}
