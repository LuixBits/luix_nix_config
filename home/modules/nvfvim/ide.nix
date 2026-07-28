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
        listImplementations = "gri";
        listReferences = "grr";

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
          workspaceDiagnostics = "<leader>xx";
          documentDiagnostics = "<leader>xb";
          lspReferences = "<leader>xr";
          quickfix = "<leader>xq";
          locList = "<leader>xl";
          symbols = "<leader>xs";
        };
      };
    };

    utility.outline.aerial-nvim = {
      enable = true;
      mappings.toggle = "<leader>oo";
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

    luaConfigRC.treesitter-textobjects-modern =
      inputs.nvf.lib.nvim.dag.entryAfter [ "treesitter-textobjects" ]
        ''
          require("nvim-treesitter-textobjects").setup({
            select = { lookahead = true },
            move = { set_jumps = true },
          })
        '';

    keymaps = [
      {
        mode = "n";
        key = "<leader>on";
        action = "<cmd>AerialNext<CR>";
        desc = "Next outline symbol";
      }
      {
        mode = "n";
        key = "<leader>op";
        action = "<cmd>AerialPrev<CR>";
        desc = "Previous outline symbol";
      }
      {
        mode = "n";
        key = "<leader>ob";
        action = "<cmd>lua require('dropbar.api').pick()<CR>";
        desc = "Pick breadcrumb";
      }
      {
        mode = "n";
        key = "<leader>oc";
        action = "<cmd>lua require('dropbar.api').goto_context_start()<CR>";
        desc = "Jump to context start";
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
        key = "<leader>xn";
        action = "<cmd>lua vim.diagnostic.jump({ count = 1, float = true })<CR>";
        desc = "Next diagnostic";
      }
      {
        mode = "n";
        key = "<leader>xp";
        action = "<cmd>lua vim.diagnostic.jump({ count = -1, float = true })<CR>";
        desc = "Previous diagnostic";
      }
      {
        mode = "n";
        key = "<leader>li";
        action = "<cmd>LspInfo<CR>";
        desc = "LSP information";
      }
      {
        mode = "n";
        key = "<leader>lv";
        action = "<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 })<CR>";
        desc = "Toggle inlay hints";
      }
      {
        mode = "n";
        key = "<leader>lg";
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
        key = "<leader>jfn";
        action = ''
          function()
            require("nvim-treesitter-textobjects.move").goto_next_start("@function.outer", "textobjects")
          end
        '';
        lua = true;
        desc = "Next function";
      }
      {
        mode = [
          "n"
          "x"
          "o"
        ];
        key = "<leader>jfp";
        action = ''
          function()
            require("nvim-treesitter-textobjects.move").goto_previous_start("@function.outer", "textobjects")
          end
        '';
        lua = true;
        desc = "Previous function";
      }
      {
        mode = [
          "n"
          "x"
          "o"
        ];
        key = "<leader>jcn";
        action = ''
          function()
            require("nvim-treesitter-textobjects.move").goto_next_start("@class.outer", "textobjects")
          end
        '';
        lua = true;
        desc = "Next class";
      }
      {
        mode = [
          "n"
          "x"
          "o"
        ];
        key = "<leader>jcp";
        action = ''
          function()
            require("nvim-treesitter-textobjects.move").goto_previous_start("@class.outer", "textobjects")
          end
        '';
        lua = true;
        desc = "Previous class";
      }
      {
        mode = "n";
        key = "<leader>jsn";
        action = ''
          function()
            require("nvim-treesitter-textobjects.swap").swap_next("@parameter.inner")
          end
        '';
        lua = true;
        desc = "Swap with next parameter";
      }
      {
        mode = "n";
        key = "<leader>jsp";
        action = ''
          function()
            require("nvim-treesitter-textobjects.swap").swap_previous("@parameter.inner")
          end
        '';
        lua = true;
        desc = "Swap with previous parameter";
      }
    ];
  };
}
