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
        action = "<cmd>NeorgPresentationStart<CR>";
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
      local presenter_pattern = "norg/Norg Presenter.norg"

      require("zen-mode").setup({
        window = {
          backdrop = 1,
          width = 1,
          height = 1,
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

      local function has_slide_heading()
        for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
          if line:match("^%*%s+%S") then
            return true
          end
        end
        return false
      end

      local function presenter_window()
        vim.opt_local.breakindent = true
        vim.opt_local.colorcolumn = ""
        vim.opt_local.concealcursor = "n"
        vim.opt_local.conceallevel = 3
        vim.opt_local.cursorcolumn = false
        vim.opt_local.cursorline = false
        vim.opt_local.foldcolumn = "0"
        vim.opt_local.foldenable = false
        vim.opt_local.linebreak = true
        vim.opt_local.list = false
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
        vim.opt_local.signcolumn = "no"
        vim.opt_local.spell = false
        vim.opt_local.statuscolumn = ""
        vim.opt_local.wrap = true
        pcall(function()
          vim.opt_local.winbar = ""
        end)
      end

      local function presenter_keymaps(buf)
        local maps = {
          q = { "<Plug>(neorg.presenter.close)", "Close presentation" },
          ["<Esc>"] = { "<Plug>(neorg.presenter.close)", "Close presentation" },
          ["<Space>"] = { "<Plug>(neorg.presenter.next-page)", "Next slide" },
          ["<Right>"] = { "<Plug>(neorg.presenter.next-page)", "Next slide" },
          ["<Down>"] = { "<Plug>(neorg.presenter.next-page)", "Next slide" },
          ["<Left>"] = { "<Plug>(neorg.presenter.previous-page)", "Previous slide" },
          ["<Up>"] = { "<Plug>(neorg.presenter.previous-page)", "Previous slide" },
          ["<BS>"] = { "<Plug>(neorg.presenter.previous-page)", "Previous slide" },
        }

        for key, map in pairs(maps) do
          vim.keymap.set("n", key, map[1], {
            buffer = buf,
            desc = map[2],
            silent = true,
          })
        end
      end

      vim.api.nvim_create_user_command("NeorgPresentationStart", function()
        if vim.bo.filetype ~= "norg" and vim.fn.expand("%:e") ~= "norg" then
          vim.notify("Neorg presenter only works in .norg files.", vim.log.levels.WARN)
          return
        end

        if not has_slide_heading() then
          vim.notify("No slides found. Use level-1 headings like '* Slide Title'.", vim.log.levels.WARN)
          return
        end

        vim.cmd("Neorg presenter start")
      end, {})

      vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
        pattern = presenter_pattern,
        callback = function(args)
          vim.b[args.buf].snacks_image_conceal = true
          presenter_window()
          presenter_keymaps(args.buf)
        end,
      })
    '';
  };
}
