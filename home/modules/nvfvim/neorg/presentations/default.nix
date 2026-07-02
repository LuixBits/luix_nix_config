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
        action = "<Plug>(luix.neorg.presenter.next-page)";
        desc = "Next slide";
      }
      {
        mode = "n";
        key = "<leader>npk";
        action = "<Plug>(luix.neorg.presenter.previous-page)";
        desc = "Previous slide";
      }
    ];

    luaConfigRC.neorg-presentations = ''
      local presenter_name = "norg/Norg Presenter.norg"
      local presenter_hl_ns = vim.api.nvim_create_namespace("luix.neorg.presenter")

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

      local function is_presenter_buffer(buf)
        if not vim.api.nvim_buf_is_valid(buf) then
          return false
        end

        return vim.api.nvim_buf_get_name(buf):match(vim.pesc(presenter_name) .. "$") ~= nil
      end

      local function presenter_highlights()
        local groups = {
          "SpellBad",
          "SpellCap",
          "SpellLocal",
          "SpellRare",
          "Underlined",
          "@markup.link",
          "@markup.link.label",
          "@markup.link.url",
          "@markup.underline",
        }

        for _, group in ipairs(groups) do
          pcall(vim.api.nvim_set_hl, presenter_hl_ns, group, {
            fg = "NONE",
            bg = "NONE",
            sp = "NONE",
            underline = false,
            undercurl = false,
            underdouble = false,
            underdotted = false,
            underdashed = false,
          })
        end

        vim.api.nvim_win_set_hl_ns(0, presenter_hl_ns)
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

      local function presenter_images(buf)
        vim.b[buf].snacks_image_conceal = true

        local ok, snacks_image = pcall(require, "snacks.image")
        if ok and snacks_image.doc and snacks_image.doc.attach then
          snacks_image.doc.attach(buf)
        end
      end

      local function presenter_hide_image_paths()
        if vim.w.luix_neorg_presenter_image_path_match then
          pcall(vim.fn.matchdelete, vim.w.luix_neorg_presenter_image_path_match)
        end

        vim.w.luix_neorg_presenter_image_path_match = vim.fn.matchadd("Conceal", "^\\s*\\.image\\s\\+.*$", 100, -1, {
          conceal = "",
        })
      end

      local function presenter_keymaps(buf)
        local maps = {
          q = { "<Plug>(neorg.presenter.close)", "Close presentation" },
          ["<Esc>"] = { "<Plug>(neorg.presenter.close)", "Close presentation" },
          ["<Space>"] = { "<Plug>(luix.neorg.presenter.next-page)", "Next slide" },
          ["<Right>"] = { "<Plug>(luix.neorg.presenter.next-page)", "Next slide" },
          ["<Down>"] = { "<Plug>(luix.neorg.presenter.next-page)", "Next slide" },
          ["<Left>"] = { "<Plug>(luix.neorg.presenter.previous-page)", "Previous slide" },
          ["<Up>"] = { "<Plug>(luix.neorg.presenter.previous-page)", "Previous slide" },
          ["<BS>"] = { "<Plug>(luix.neorg.presenter.previous-page)", "Previous slide" },
        }

        for key, map in pairs(maps) do
          vim.keymap.set("n", key, map[1], {
            buffer = buf,
            desc = map[2],
            silent = true,
          })
        end
      end

      local function apply_presenter_fixes(buf)
        buf = buf or vim.api.nvim_get_current_buf()
        if not is_presenter_buffer(buf) then
          return
        end

        presenter_highlights()
        presenter_window()
        presenter_images(buf)
        presenter_hide_image_paths()
        presenter_keymaps(buf)
      end

      local function apply_presenter_fixes_later(buf)
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(buf) then
            apply_presenter_fixes(buf)
          end
        end)
      end

      local function feed_plug(plug)
        local keys = vim.api.nvim_replace_termcodes(plug, true, false, true)
        vim.api.nvim_feedkeys(keys, "m", false)
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
        apply_presenter_fixes_later(vim.api.nvim_get_current_buf())
      end, {})

      vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
        callback = function(args)
          apply_presenter_fixes(args.buf)
        end,
      })

      vim.keymap.set("n", "<Plug>(luix.neorg.presenter.next-page)", function()
        feed_plug("<Plug>(neorg.presenter.next-page)")
        apply_presenter_fixes_later(vim.api.nvim_get_current_buf())
      end, { silent = true })

      vim.keymap.set("n", "<Plug>(luix.neorg.presenter.previous-page)", function()
        feed_plug("<Plug>(neorg.presenter.previous-page)")
        apply_presenter_fixes_later(vim.api.nvim_get_current_buf())
      end, { silent = true })
    '';
  };
}
