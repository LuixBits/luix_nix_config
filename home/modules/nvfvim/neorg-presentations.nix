{
  config,
  pkgs,
  ...
}: let
  notesDir = "${config.home.homeDirectory}/notes";
in
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
      local notes_dir = vim.fn.expand(${builtins.toJSON notesDir})
      local presenter_pattern = "norg/Norg Presenter.norg"
      local presenter_buffers = {}
      local presenter_image_original = nil
      local presenter_hl_ns = vim.api.nvim_create_namespace("luix-neorg-presenter")

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

      local function setup_presenter_theme()
        vim.api.nvim_set_hl(presenter_hl_ns, "Normal", { fg = "#dcd7ba", bg = "#1f1f28" })
        vim.api.nvim_set_hl(presenter_hl_ns, "NormalNC", { fg = "#dcd7ba", bg = "#1f1f28" })
        vim.api.nvim_set_hl(presenter_hl_ns, "EndOfBuffer", { fg = "#1f1f28", bg = "#1f1f28" })
        vim.api.nvim_set_hl(presenter_hl_ns, "NonText", { fg = "#54546d" })
        vim.api.nvim_set_hl(presenter_hl_ns, "SignColumn", { bg = "#1f1f28" })
        vim.api.nvim_set_hl(presenter_hl_ns, "FoldColumn", { bg = "#1f1f28" })
        vim.api.nvim_set_hl(presenter_hl_ns, "LineNr", { fg = "#54546d", bg = "#1f1f28" })
        vim.api.nvim_set_hl(presenter_hl_ns, "CursorLine", { bg = "#1f1f28" })
        vim.api.nvim_set_hl(presenter_hl_ns, "SpellBad", {})
        vim.api.nvim_set_hl(presenter_hl_ns, "DiagnosticUnderlineError", {})
        vim.api.nvim_set_hl(presenter_hl_ns, "DiagnosticUnderlineWarn", {})
        vim.api.nvim_set_hl(presenter_hl_ns, "DiagnosticUnderlineInfo", {})
        vim.api.nvim_set_hl(presenter_hl_ns, "DiagnosticUnderlineHint", {})
        vim.api.nvim_set_hl(presenter_hl_ns, "@neorg.headings.1.prefix", { fg = "#7e9cd8", bold = true })
        vim.api.nvim_set_hl(presenter_hl_ns, "@neorg.headings.1.title", { fg = "#7e9cd8", bold = true })
        vim.api.nvim_set_hl(presenter_hl_ns, "@neorg.modifiers.link", { fg = "#7fb4ca" })
        vim.api.nvim_set_hl(presenter_hl_ns, "@neorg.links.location.url", { fg = "#7fb4ca", underline = true })
        vim.api.nvim_set_hl(presenter_hl_ns, "@neorg.tags.ranged_verbatim.document_meta.key", { fg = "#727169" })
        vim.api.nvim_set_hl(presenter_hl_ns, "@neorg.tags.ranged_verbatim.document_meta.string", { fg = "#727169" })
        vim.api.nvim_set_hl(presenter_hl_ns, "@neorg.tags.ranged_verbatim.name", { fg = "#98bb6c" })
        vim.api.nvim_set_hl(presenter_hl_ns, "@neorg.tags.ranged_verbatim.parameters", { fg = "#e6c384" })
        vim.api.nvim_set_hl(presenter_hl_ns, "@neorg.error", { fg = "#dcd7ba", bg = "#1f1f28" })
      end

      local function set_buffer_diagnostics_enabled(buf, enabled)
        if vim.diagnostic and vim.diagnostic.enable then
          pcall(vim.diagnostic.enable, enabled, { bufnr = buf })
        elseif vim.diagnostic then
          if enabled and vim.diagnostic.enable then
            pcall(vim.diagnostic.enable, buf)
          elseif vim.diagnostic.disable then
            pcall(vim.diagnostic.disable, buf)
          end
        end
      end

      local function hide_buffer_diagnostics(buf)
        if not vim.diagnostic then
          return
        end

        if vim.diagnostic.hide then
          pcall(vim.diagnostic.hide, nil, buf)
        end

        set_buffer_diagnostics_enabled(buf, false)
      end

      local function snacks_image_doc_config()
        local snacks = rawget(_G, "Snacks")

        if snacks and snacks.image and snacks.image.config and snacks.image.config.doc then
          return snacks.image.config.doc
        end

        local ok, image = pcall(require, "snacks.image")
        if ok and image.config and image.config.doc then
          return image.config.doc
        end

        return nil
      end

      local function remember_image_config(doc)
        if presenter_image_original then
          return
        end

        presenter_image_original = {
          max_width = doc.max_width,
          max_height = doc.max_height,
        }
      end

      local function restore_image_config_if_idle()
        for buf, _ in pairs(presenter_buffers) do
          if vim.api.nvim_buf_is_valid(buf) then
            return
          end
        end

        local doc = snacks_image_doc_config()
        if doc and presenter_image_original then
          doc.max_width = presenter_image_original.max_width
          doc.max_height = presenter_image_original.max_height
        end

        presenter_image_original = nil
      end

      local function count_presenter_text_rows(buf)
        local rows = 0
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

        for _, line in ipairs(lines) do
          local trimmed = vim.trim(line)

          if trimmed ~= "" and not trimmed:match("^%.image%s+") then
            rows = rows + 1
          end
        end

        return rows
      end

      local function apply_presenter_image_config(buf)
        if not vim.api.nvim_buf_is_valid(buf) then
          return
        end

        local doc = snacks_image_doc_config()
        if not doc then
          return
        end

        remember_image_config(doc)

        local win = vim.fn.bufwinid(buf)
        local width = win ~= -1 and vim.api.nvim_win_get_width(win) or vim.o.columns
        local height = win ~= -1 and vim.api.nvim_win_get_height(win) or vim.o.lines
        local horizontal_margin = math.max(4, math.floor(width * 0.06))
        local text_rows = count_presenter_text_rows(buf)

        doc.max_width = math.max(24, width - horizontal_margin)
        doc.max_height = math.max(1, height - text_rows - 3)
      end

      local function schedule_presenter_image_config(buf)
        vim.schedule(function()
          apply_presenter_image_config(buf)
        end)
      end

      local function strip_quotes(value)
        return value:gsub("^['\"]", ""):gsub("['\"]$", "")
      end

      local function resolve_presentation_path(src)
        if type(src) ~= "string" then
          return nil
        end

        src = strip_quotes(vim.trim(src))
        if src == "" then
          return nil
        end

        if vim.startswith(src, "~/") then
          return vim.fn.expand(src)
        end

        if src == "$notes" then
          return notes_dir
        end

        if vim.startswith(src, "$notes/") then
          return vim.fs.normalize(notes_dir .. "/" .. src:sub(8))
        end

        if vim.startswith(src, "$") then
          local ok, neorg = pcall(require, "neorg.core")
          if ok then
            local ok_utils, dirman_utils = pcall(neorg.modules.get_module, "core.dirman.utils")
            if ok_utils and dirman_utils then
              local expanded = dirman_utils.expand_path(src, true)
              if expanded then
                return expanded
              end
            end
          end
        end

        if src:match("^/") then
          return src
        end

        local current_file = vim.api.nvim_buf_get_name(0)
        local current_dir = current_file ~= "" and vim.fn.fnamemodify(current_file, ":p:h") or vim.loop.cwd()

        return vim.fs.normalize(current_dir .. "/" .. src)
      end

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
          "  - One sentence that frames the audience and goal.",
          "  - Why this matters now.",
          "",
          "* Problem",
          "  - Current state.",
          "  - Main friction.",
          "",
          "* Model",
          "  - Core idea.",
          "  - Key moving parts.",
          "",
          "* Demo",
          "  - Setup.",
          "  - Walkthrough.",
          "",
          "* Takeaway",
          "  - What changed.",
          "  - Next step.",
          "",
          "* Appendix",
          "  - Optional backup material.",
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

      local function collect_presentation_warnings()
        local warnings = {}
        local slides = {}
        local current = nil
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

        for lnum, line in ipairs(lines) do
          if line:match("^%*%s+%S") then
            current = {
              title = vim.trim(line:gsub("^%*%s+", "")),
              lnum = lnum,
              bullets = 0,
              images = 0,
            }
            table.insert(slides, current)
          elseif current then
            local trimmed = vim.trim(line)

            if trimmed:match("^[-+~]%s+") or trimmed:match("^%d+[.)]%s+") then
              current.bullets = current.bullets + 1
            end

            local image_src = trimmed:match("^%.image%s+(.+)$")
            if image_src then
              current.images = current.images + 1

              local resolved = resolve_presentation_path(image_src)
              if not resolved or vim.fn.filereadable(resolved) == 0 then
                local label = current.title ~= "" and current.title or ("Slide at line " .. current.lnum)
                table.insert(warnings, label .. ": image not found: " .. vim.trim(image_src))
              end
            end
          end
        end

        if vim.tbl_isempty(slides) then
          table.insert(warnings, "No slides found. Add level-1 headings like '* Slide Title'.")
          return warnings
        end

        for _, slide in ipairs(slides) do
          local label = slide.title ~= "" and slide.title or ("Slide at line " .. slide.lnum)

          if slide.bullets > 6 then
            table.insert(warnings, label .. ": " .. slide.bullets .. " bullet lines; aim for 6 or fewer.")
          end

          if slide.images > 0 and slide.bullets > 4 then
            table.insert(warnings, label .. ": image plus " .. slide.bullets .. " bullets may crowd the slide.")
          end
        end

        return warnings
      end

      local function notify_presentation_warnings(warnings, success_message)
        if vim.tbl_isempty(warnings) then
          if success_message then
            vim.notify(success_message, vim.log.levels.INFO, { title = "Neorg presentation check" })
          end
          return true
        end

        local shown = {}
        local limit = math.min(#warnings, 8)

        for i = 1, limit do
          table.insert(shown, warnings[i])
        end

        if #warnings > limit then
          table.insert(shown, "... " .. (#warnings - limit) .. " more warning(s)")
        end

        vim.notify(table.concat(shown, "\n"), vim.log.levels.WARN, { title = "Neorg presentation check" })
        return false
      end

      local function run_presentation_preflight(opts)
        opts = opts or {}
        local warnings = collect_presentation_warnings()
        return notify_presentation_warnings(warnings, opts.success_message)
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

        run_presentation_preflight()

        vim.schedule(function()
          vim.cmd("Neorg presenter start")
        end)
      end, {})

      vim.api.nvim_create_user_command("NeorgPresentationCheck", function()
        run_presentation_preflight({ success_message = "Presentation check passed." })
      end, {})

      local function run_presenter_action(action, buf)
        local ok, neorg = pcall(require, "neorg.core")
        if not ok then
          return
        end

        local ok_presenter, presenter = pcall(neorg.modules.get_module, "core.presenter")
        local public = ok_presenter and presenter and (presenter.public or presenter) or nil
        if not public then
          return
        end

        local fn = public[action]
        if type(fn) ~= "function" then
          return
        end

        fn()

        if action ~= "close" then
          schedule_presenter_image_config(buf)
        end
      end

      local function configure_presenter_buffer(buf)
        setup_presenter_theme()

        presenter_buffers[buf] = true
        vim.b[buf].snacks_image_conceal = true

        hide_buffer_diagnostics(buf)
        apply_presenter_image_config(buf)

        if not vim.b[buf].luix_presenter_attached then
          vim.b[buf].luix_presenter_attached = true

          pcall(vim.api.nvim_buf_attach, buf, false, {
            on_lines = function()
              schedule_presenter_image_config(buf)
            end,
            on_detach = function()
              presenter_buffers[buf] = nil
              restore_image_config_if_idle()
            end,
          })
        end
      end

      local function configure_presenter_window(buf)
        vim.api.nvim_win_set_hl_ns(0, presenter_hl_ns)

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

        local function map(key, action, desc)
          vim.keymap.set("n", key, function()
            run_presenter_action(action, buf)
          end, {
            buffer = buf,
            desc = desc,
            silent = true,
          })
        end

        map("q", "close", "Close presentation")
        map("<Esc>", "close", "Close presentation")
        map("<Space>", "next_page", "Next slide")
        map("<Right>", "next_page", "Next slide")
        map("<Down>", "next_page", "Next slide")
        map("<Left>", "previous_page", "Previous slide")
        map("<Up>", "previous_page", "Previous slide")
        map("<BS>", "previous_page", "Previous slide")
      end

      vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
        pattern = presenter_pattern,
        callback = function(args)
          configure_presenter_buffer(args.buf)
          configure_presenter_window(args.buf)
        end,
      })

      vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
        pattern = presenter_pattern,
        callback = function(args)
          presenter_buffers[args.buf] = nil
          restore_image_config_if_idle()
        end,
      })

      local function refresh_open_presenters()
        for buf, _ in pairs(presenter_buffers) do
          if vim.api.nvim_buf_is_valid(buf) and vim.fn.bufwinid(buf) ~= -1 then
            apply_presenter_image_config(buf)
          end
        end
      end

      vim.api.nvim_create_autocmd("VimResized", {
        callback = refresh_open_presenters,
      })

      pcall(vim.api.nvim_create_autocmd, "WinResized", {
        callback = refresh_open_presenters,
      })
    '';
  };
}
