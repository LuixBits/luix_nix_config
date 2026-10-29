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

      local function fit_presenter_image(placement)
        if not is_presenter_buffer(placement.buf) then
          return
        end

        local win = placement:wins()[1]
        if not win then
          return
        end
        local width = vim.api.nvim_win_get_width(win)
        local height = vim.api.nvim_win_get_height(win)
        local text_rows = 0
        for _, line in ipairs(vim.api.nvim_buf_get_lines(placement.buf, 0, -1, false)) do
          if not line:match("^%s*%.image%s+") then
            text_rows = text_rows + math.max(1, math.ceil(vim.fn.strdisplaywidth(line) / width))
          end
        end
        placement.opts.max_width = math.max(1, width - 4)
        placement.opts.max_height = math.max(1, height - text_rows - 2)
        placement.presenter_image_left = math.max(0, math.floor((width - placement:state().loc.width) / 2))

        if placement.presenter_image_centered then
          return
        end
        placement.presenter_image_centered = true
        -- Keep the source range intact; center only the rendered image placeholders.
        local render = placement._render
        placement._render = function(self, marks)
          local padding = string.rep(" ", self.presenter_image_left)
          for _, mark in ipairs(marks) do
            if mark.virt_text_pos == "overlay" then
              mark.virt_text_win_col = self.presenter_image_left
            end
            for _, line in ipairs(mark.virt_lines or {}) do
              if not line[1][2] then
                line[1][1] = padding
              else
                table.insert(line, 1, { padding })
              end
            end
          end
          return render(self, marks)
        end
        vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
          group = placement.augroup,
          callback = function()
            if not placement.closed then
              placement:update()
            end
          end,
        })
      end

      local function presenter_images(buf)
        vim.b[buf].snacks_image_conceal = true

        local ok, snacks_image = pcall(require, "snacks.image")
        if not ok or not snacks_image.doc or not snacks_image.doc.attach then
          return
        end
        if not snacks_image.presenter_layout_installed then
          snacks_image.presenter_layout_installed = true
          local previous = snacks_image.config.doc.on_update_pre
          snacks_image.config.doc.on_update_pre = function(placement)
            if previous then
              previous(placement)
            end
            fit_presenter_image(placement)
          end
        end
        snacks_image.doc.attach(buf)
        -- Also update images already attached before the presenter window was ready.
        for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
          local src = line:match("^%s*%.image%s+(.+)$")
          if src then
            local img = snacks_image.image.new(snacks_image.doc.resolve(buf, src))
            for _, placement in pairs(img.placements) do
              if placement.buf == buf then
                placement.opts.on_update_pre = snacks_image.config.doc.on_update_pre
                placement:update()
              end
            end
          end
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
          j = { "<Plug>(luix.neorg.presenter.next-page)", "Next slide" },
          k = { "<Plug>(luix.neorg.presenter.previous-page)", "Previous slide" },
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
