{ pkgs, ... }:
{
  home.packages = [
    pkgs.imagemagick
  ];

  programs.nvf.settings.vim = {
    startPlugins = [
      pkgs.vimPlugins.image-nvim
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
      local presentation_state = {
        source_file = "",
      }

      require("image").setup({
        backend = "kitty",
        processor = "magick_cli",
        integrations = {
          markdown = { enabled = false },
          neorg = {
            enabled = true,
            filetypes = { "norg" },
            clear_in_insert_mode = false,
            download_remote_images = true,
            only_render_image_at_cursor = false,
            resolve_image_path = function(document_path, image_path, fallback)
              if document_path:match("Norg Presenter%.norg$") and presentation_state.source_file ~= "" then
                return fallback(presentation_state.source_file, image_path)
              end

              return fallback(document_path, image_path)
            end,
          },
        },
        max_height_window_percentage = 65,
        window_overlap_clear_enabled = false,
        editor_only_render_when_focused = false,
        hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
      })

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

      local function has_level_one_heading()
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

        for _, line in ipairs(lines) do
          if line:match("^%*%s+%S") then
            return true
          end
        end

        return false
      end

      local function is_blank_or_metadata_only()
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

        for _, line in ipairs(lines) do
          local trimmed = vim.trim(line)

          if trimmed ~= ""
            and trimmed ~= "@document.meta"
            and trimmed ~= "@end"
            and not trimmed:match("^[%w_-]+:%s*.*$")
          then
            return false
          end
        end

        return true
      end

      local function presentation_title()
        local title = vim.fn.expand("%:t:r")

        if title == "" then
          return "Presentation"
        end

        title = title:gsub("[_-]+", " ")
        return title:gsub("^%l", string.upper)
      end

      local function insert_minimal_presentation()
        local title = presentation_title()
        local skeleton = {
          "* " .. title,
          "  Placeholder opening text.",
          "",
          "* Main Point",
          "  Placeholder explanation.",
          "",
          "* Demo",
          "  Placeholder demo notes.",
          "",
          "* Closing",
          "  Placeholder takeaway.",
        }
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        local is_empty = true

        for _, line in ipairs(lines) do
          if vim.trim(line) ~= "" then
            is_empty = false
            break
          end
        end

        if is_empty then
          vim.api.nvim_buf_set_lines(0, 0, -1, false, skeleton)
        else
          if vim.trim(lines[#lines] or "") ~= "" then
            table.insert(skeleton, 1, "")
          end

          vim.api.nvim_buf_set_lines(0, -1, -1, false, skeleton)
        end
      end

      vim.api.nvim_create_user_command("NeorgPresentationStart", function()
        if vim.bo.filetype ~= "norg" and vim.fn.expand("%:e") ~= "norg" then
          vim.notify("Neorg presenter only works in .norg files.", vim.log.levels.WARN)
          return
        end

        if not has_level_one_heading() then
          if is_blank_or_metadata_only() then
            insert_minimal_presentation()
            vim.notify("Added a minimal presentation skeleton.", vim.log.levels.INFO)
          else
            vim.notify("No slides found. Add level-1 headings like '* Slide Title' before starting presenter.", vim.log.levels.WARN)
            return
          end
        end

        presentation_state.source_file = vim.api.nvim_buf_get_name(0)

        vim.schedule(function()
          vim.cmd("Neorg presenter start")
        end)
      end, {})

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
