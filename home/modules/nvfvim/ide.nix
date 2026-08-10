{
  inputs,
  pkgs,
  ...
}:
{
  programs.nvf.settings.vim = {
    # Keep semantic navigation close to Neovim's modern defaults. These are
    # buffer-local and appear only when an LSP attaches.
    lsp = {
      mappings = {
        goToDefinition = "gd";
        goToDeclaration = "gD";
        goToType = "grt";
        listImplementations = null;
        listReferences = null;

        nextDiagnostic = null;
        previousDiagnostic = null;
        openDiagnosticFloat = null;
        documentHighlight = null;
        listDocumentSymbols = null;
        addWorkspaceFolder = null;
        removeWorkspaceFolder = null;
        listWorkspaceFolders = null;
        listWorkspaceSymbols = "<leader>lw";

        hover = "K";
        signatureHelp = "<leader>ls";
        renameSymbol = "grn";
        codeAction = "gra";
        format = null;
        toggleFormatOnSave = null;
      };

      trouble = {
        enable = true;
        mappings = {
          workspaceDiagnostics = null;
          documentDiagnostics = null;
          lspReferences = null;
          quickfix = null;
          locList = null;
          symbols = null;
        };
        setupOpts = {
          focus = true;
          # Give current-file diagnostics their own mode so Trouble does not
          # reuse a project-wide view with the wrong filter (or vice versa).
          modes.buffer_diagnostics = {
            mode = "diagnostics";
            desc = "current-file diagnostics";
            filter.buf = 0;
          };
          keys = {
            "<cr>" = "jump_close";
            o = "jump_close";
          };
        };
      };
    };

    utility.outline.aerial-nvim = {
      enable = true;
      # Opening and focusing are one predictable action. Close the outline
      # with q while it is focused.
      mappings.toggle = null;
      setupOpts = {
        backends = [
          "lsp"
          "treesitter"
          "markdown"
          "man"
        ];
        layout = {
          default_direction = "prefer_right";
          min_width = 30;
        };
        show_guides = true;
        keymaps = {
          "<C-j>" = false;
          "<C-k>" = false;
          h = "actions.tree_close";
          l = "actions.tree_open";
          "<CR>" = "actions.jump";
          q = "actions.close";
        };
      };
    };

    treesitter = {
      context = {
        enable = true;
        setupOpts = {
          max_lines = 4;
          multiline_threshold = 1;
          trim_scope = "outer";
          mode = "cursor";
          separator = "─";
        };
      };

      # NVF installs the plugin. Explicit modern-API setup and maps below are
      # needed because current nvim-treesitter-textobjects no longer creates
      # mappings from nvim-treesitter's legacy `textobjects` table.
      textobjects.enable = true;
    };

    # Dropbar provides interactive path/LSP/Tree-sitter breadcrumbs. The
    # plugin is zero-config; its public API powers the mappings below.
    startPlugins = [
      pkgs.vimPlugins.dropbar-nvim
      pkgs.vimPlugins.gdscript-extended-lsp-nvim
    ];

    luaConfigRC.gdscript-extended-lsp = inputs.nvf.lib.nvim.dag.entryAfter [ "lsp-servers" ] ''
      require("gdscript-extended-lsp").setup({
        picker = "telescope",
        view_type = "vsplit",
        keymaps = {
          declaration = "gD",
          close = { "q", "<Esc>" },
        },
      })
    '';

    # Use the same searchable picker for usages and implementations. These
    # buffer-local mappings replace Neovim's built-in quickfix-style lists.
    luaConfigRC.lsp-picker-mappings = inputs.nvf.lib.nvim.dag.entryAfter [ "lsp-servers" ] ''
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          vim.keymap.set("n", "grr", function()
            require("telescope.builtin").lsp_references()
          end, {
            buffer = args.buf,
            desc = "Find symbol usages",
          })
          vim.keymap.set("n", "gri", function()
            require("telescope.builtin").lsp_implementations()
          end, {
            buffer = args.buf,
            desc = "Find implementations",
          })
          vim.keymap.set("n", "<leader>fs", function()
            require("telescope.builtin").lsp_document_symbols()
          end, {
            buffer = args.buf,
            desc = "Find document symbols",
          })
        end,
      })
    '';

    luaConfigRC.treesitter-textobjects-modern =
      inputs.nvf.lib.nvim.dag.entryAfter [ "treesitter-textobjects" ]
        ''
          require("nvim-treesitter-textobjects").setup({
            select = { lookahead = true },
            move = { set_jumps = true },
          })
        '';

    # Python's Tree-sitter query reports a decorated function twice: once at
    # its decorator and once at `def`. Skip the inner duplicate so one keypress
    # always means one logical function or class. Other languages keep the
    # plugin's normal movement unchanged.
    luaConfigRC.treesitter-logical-movement =
      inputs.nvf.lib.nvim.dag.entryAfter [ "treesitter-textobjects-modern" ]
        ''
          LuixTreesitterMove = {}

          local textobject_move = require("nvim-treesitter-textobjects.move")

          local function is_decorated_duplicate()
            if vim.bo.filetype ~= "python" then
              return false
            end

            local cursor = vim.api.nvim_win_get_cursor(0)
            local node = vim.treesitter.get_node()
            while node do
              local node_type = node:type()
              if node_type == "function_definition" or node_type == "class_definition" then
                local row, column = node:start()
                local parent = node:parent()
                return parent ~= nil
                  and parent:type() == "decorated_definition"
                  and row + 1 == cursor[1]
                  and column == cursor[2]
              end
              node = node:parent()
            end

            return false
          end

          local function move_once(direction, capture)
            textobject_move[direction](capture, "textobjects")
            if is_decorated_duplicate() then
              textobject_move[direction](capture, "textobjects")
            end
          end

          LuixTreesitterMove.next = function(capture)
            move_once("goto_next_start", capture)
          end

          LuixTreesitterMove.previous = function(capture)
            move_once("goto_previous_start", capture)
          end
        '';

    keymaps = [
      {
        mode = "n";
        key = "<leader>xx";
        action = ''
          function()
            local trouble = require("trouble")
            trouble.close("buffer_diagnostics")
            trouble.close("lsp_references")
            local view = trouble.open("diagnostics")
            if view then
              view:action("first")
            end
          end
        '';
        lua = true;
        desc = "Open or focus all problems";
      }
      {
        mode = "n";
        key = "<leader>xb";
        action = ''
          function()
            local trouble = require("trouble")
            trouble.close("diagnostics")
            trouble.close("lsp_references")
            local view = trouble.open("buffer_diagnostics")
            if view then
              view:action("first")
            end
          end
        '';
        lua = true;
        desc = "Open or focus current-file problems";
      }
      {
        mode = "n";
        key = "<leader>xr";
        action = ''
          function()
            local trouble = require("trouble")
            trouble.close("diagnostics")
            trouble.close("buffer_diagnostics")
            local view = trouble.open("lsp_references")
            if view then
              view:action("first")
            end
          end
        '';
        lua = true;
        desc = "Open or focus symbol usages";
      }
      {
        mode = "n";
        key = "<leader>oo";
        action = "<cmd>AerialOpen<CR>";
        desc = "Open or focus code outline";
      }
      {
        mode = "n";
        key = "<leader>ob";
        action = "<cmd>lua require('dropbar.api').pick()<CR>";
        desc = "Pick breadcrumb";
      }
      {
        mode = "n";
        key = "<leader>jt";
        action = "<cmd>lua require('treesitter-context').toggle()<CR>";
        desc = "Toggle syntax context";
      }
      {
        mode = "n";
        key = "<leader>xd";
        action = "<cmd>lua vim.diagnostic.open_float()<CR>";
        desc = "Line diagnostic";
      }
      {
        mode = "n";
        key = "<leader>xj";
        action = "<cmd>lua vim.diagnostic.jump({ count = 1, float = true })<CR>";
        desc = "Next diagnostic (down)";
      }
      {
        mode = "n";
        key = "<leader>xk";
        action = "<cmd>lua vim.diagnostic.jump({ count = -1, float = true })<CR>";
        desc = "Previous diagnostic (up)";
      }
      {
        mode = "n";
        key = "<leader>li";
        action = "<cmd>checkhealth vim.lsp<CR>";
        desc = "LSP health and clients";
      }
      {
        mode = "n";
        key = "<leader>lv";
        action = "<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 })<CR>";
        desc = "Toggle inlay hints";
      }
      {
        mode = "n";
        key = "<leader>ld";
        action = "<cmd>lua require('gdscript-extended-lsp').pick()<CR>";
        desc = "Find Godot documentation";
      }
      {
        mode = [
          "x"
          "o"
        ];
        key = "af";
        action = ''
          function()
            require("nvim-treesitter-textobjects.select").select_textobject("@function.outer", "textobjects")
          end
        '';
        lua = true;
        desc = "Around function";
      }
      {
        mode = [
          "x"
          "o"
        ];
        key = "if";
        action = ''
          function()
            require("nvim-treesitter-textobjects.select").select_textobject("@function.inner", "textobjects")
          end
        '';
        lua = true;
        desc = "Inside function";
      }
      {
        mode = [
          "x"
          "o"
        ];
        key = "ac";
        action = ''
          function()
            require("nvim-treesitter-textobjects.select").select_textobject("@class.outer", "textobjects")
          end
        '';
        lua = true;
        desc = "Around class";
      }
      {
        mode = [
          "x"
          "o"
        ];
        key = "ic";
        action = ''
          function()
            require("nvim-treesitter-textobjects.select").select_textobject("@class.inner", "textobjects")
          end
        '';
        lua = true;
        desc = "Inside class";
      }
      {
        mode = [
          "x"
          "o"
        ];
        key = "aa";
        action = ''
          function()
            require("nvim-treesitter-textobjects.select").select_textobject("@parameter.outer", "textobjects")
          end
        '';
        lua = true;
        desc = "Around parameter";
      }
      {
        mode = [
          "x"
          "o"
        ];
        key = "ia";
        action = ''
          function()
            require("nvim-treesitter-textobjects.select").select_textobject("@parameter.inner", "textobjects")
          end
        '';
        lua = true;
        desc = "Inside parameter";
      }
      {
        mode = [
          "n"
          "x"
          "o"
        ];
        key = "<leader>jfj";
        action = ''
          function()
            LuixTreesitterMove.next("@function.outer")
          end
        '';
        lua = true;
        desc = "Next function (down)";
      }
      {
        mode = [
          "n"
          "x"
          "o"
        ];
        key = "<leader>jfk";
        action = ''
          function()
            LuixTreesitterMove.previous("@function.outer")
          end
        '';
        lua = true;
        desc = "Previous function (up)";
      }
      {
        mode = [
          "n"
          "x"
          "o"
        ];
        key = "<leader>jcj";
        action = ''
          function()
            LuixTreesitterMove.next("@class.outer")
          end
        '';
        lua = true;
        desc = "Next class (down)";
      }
      {
        mode = [
          "n"
          "x"
          "o"
        ];
        key = "<leader>jck";
        action = ''
          function()
            LuixTreesitterMove.previous("@class.outer")
          end
        '';
        lua = true;
        desc = "Previous class (up)";
      }
      {
        mode = "n";
        key = "<leader>jsl";
        action = ''
          function()
            require("nvim-treesitter-textobjects.swap").swap_next("@parameter.inner")
          end
        '';
        lua = true;
        desc = "Swap parameter right";
      }
      {
        mode = "n";
        key = "<leader>jsh";
        action = ''
          function()
            require("nvim-treesitter-textobjects.swap").swap_previous("@parameter.inner")
          end
        '';
        lua = true;
        desc = "Swap parameter left";
      }
    ];
  };
}
