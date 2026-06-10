{ pkgs, ... }:
{
  programs.nvf.settings.vim = {
    startPlugins = [
      pkgs.vimPlugins.zen-mode-nvim
    ];

    notes.neorg.setupOpts.load."core.presenter" = {
      config.zen_mode = "zen-mode";
    };

    binds.whichKey.register."<leader>np" = "+Present";

    keymaps = [
      {
        mode = "n";
        key = "<leader>nps";
        action = "<cmd>Neorg presenter start<CR>";
        desc = "Start presentation";
      }
      {
        mode = "n";
        key = "<leader>npq";
        action = "<Plug>(neorg.presenter.close)";
        desc = "Stop presentation";
      }
      {
        mode = "n";
        key = "<leader>npj";
        action = "<Plug>(neorg.presenter.next-page)";
        desc = "Next slide";
      }
      {
        mode = "n";
        key = "<leader>npk";
        action = "<Plug>(neorg.presenter.previous-page)";
        desc = "Previous slide";
      }
    ];

    luaConfigRC.neorg-presentations = ''
      require("zen-mode").setup({
        window = {
          backdrop = 0.95,
          width = 0.9,
          height = 0.95,
          options = {
            cursorline = false,
            foldcolumn = "0",
            list = false,
            number = false,
            relativenumber = false,
            signcolumn = "no",
          },
        },
        plugins = {
          gitsigns = { enabled = false },
          options = {
            enabled = true,
            laststatus = 0,
            ruler = false,
            showcmd = false,
          },
          todo = { enabled = false },
          twilight = { enabled = false },
        },
      })

      vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
        pattern = "norg/Norg Presenter.norg",
        callback = function(args)
          local function map(key, action, desc)
            vim.keymap.set("n", key, action, {
              buffer = args.buf,
              desc = desc,
              silent = true,
            })
          end

          map("q", "<Plug>(neorg.presenter.close)", "Close presentation")
          map("<Esc>", "<Plug>(neorg.presenter.close)", "Close presentation")
          map("<Space>", "<Plug>(neorg.presenter.next-page)", "Next slide")
          map("<Right>", "<Plug>(neorg.presenter.next-page)", "Next slide")
          map("<Down>", "<Plug>(neorg.presenter.next-page)", "Next slide")
          map("<Left>", "<Plug>(neorg.presenter.previous-page)", "Previous slide")
          map("<Up>", "<Plug>(neorg.presenter.previous-page)", "Previous slide")
          map("<BS>", "<Plug>(neorg.presenter.previous-page)", "Previous slide")
        end,
      })
    '';
  };
}
