{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.generators) mkLuaInline;
in
{
  programs.nvf.settings.vim = {
    debugger.nvim-dap = {
      enable = true;

      ui = {
        enable = true;
        autoStart = true;
        setupOpts.floating.border = "rounded";
        # Stack-frame rows provide an `open` action rather than `expand`.
        # Make Enter select the frame, matching the other focused tool views.
        setupOpts.element_mappings.stacks = {
          expand = [ ];
          open = [
            "<CR>"
            "o"
          ];
        };
      };

      presets = {
        debugpy.enable = true;
        xdebug.enable = true;
      };

      adapters = {
        pwa-node = {
          type = "server";
          host = "127.0.0.1";
          port = "\${port}";
          executable = {
            command = lib.getExe pkgs.vscode-js-debug;
            args = [
              "\${port}"
              "127.0.0.1"
            ];
          };
        };

        pwa-chrome = {
          type = "server";
          host = "127.0.0.1";
          port = "\${port}";
          executable = {
            command = lib.getExe pkgs.vscode-js-debug;
            args = [
              "\${port}"
              "127.0.0.1"
            ];
          };
        };

        godot = {
          type = "server";
          host = "127.0.0.1";
          port = 6006;
        };
      };

      configurations =
        let
          node = {
            type = "pwa-node";
            request = "launch";
            name = "Node: current file";
            program = "\${file}";
            cwd = "\${workspaceFolder}";
            sourceMaps = true;
            console = "integratedTerminal";
          };

          browser = {
            type = "pwa-chrome";
            request = "launch";
            name = "Browser: Vite on port 5173";
            url = mkLuaInline ''
              function()
                return vim.fn.input("Application URL: ", "http://localhost:5173")
              end
            '';
            webRoot = mkLuaInline ''
              function()
                return vim.fs.root(0, {
                  "vite.config.ts",
                  "vite.config.js",
                  "package.json",
                  ".git",
                }) or vim.uv.cwd()
              end
            '';
            runtimeExecutable = lib.getExe pkgs.chromium;
            sourceMaps = true;
          };
        in
        {
          php = [
            {
              type = "xdebug";
              request = "launch";
              name = "PHP: listen for Xdebug";
              port = 9003;
            }
          ];

          python = [
            {
              type = "debugpy";
              request = "launch";
              name = "Python: current file";
              program = "\${file}";
              cwd = "\${workspaceFolder}";
              console = "integratedTerminal";
              justMyCode = false;
            }
          ];

          javascript = [
            node
            browser
          ];
          javascriptreact = [
            node
            browser
          ];
          typescript = [
            node
            browser
          ];
          typescriptreact = [
            node
            browser
          ];
          vue = [ browser ];
          svelte = [ browser ];

          gdscript = [
            {
              type = "godot";
              request = "launch";
              name = "Godot: launch scene";
              project = "\${workspaceFolder}";
              launch_scene = true;
            }
          ];
        };

      # All debugger maps use letters that are easy to reach on a Swiss
      # keyboard. The longer operations are grouped under <leader>d.
      mappings = {
        toggleBreakpoint = "<leader>db";
        continue = "<leader>dc";
        restart = "<leader>da";
        terminate = "<leader>dq";
        runLast = "<leader>dl";
        toggleRepl = "<leader>dr";
        hover = "<leader>dh";
        runToCursor = "<leader>dg";
        stepInto = "<leader>di";
        stepOut = "<leader>do";
        stepOver = "<leader>dj";
        # Reverse stepping is unsupported by most of our adapters. Stack
        # frames are selected with j/k and Enter in the debugger panels.
        stepBack = null;
        goUp = null;
        goDown = null;
        toggleDapUI = null;
      };

      # Neotest adapters use the conventional names `python` and `php`.
      # Point those names at the modern adapters configured by NVF.
      sources.neotest-adapter-aliases = ''
        local dap = require("dap")
        dap.adapters.python = dap.adapters.debugpy
        dap.adapters.php = dap.adapters.xdebug
      '';
    };

    startPlugins = [ pkgs.vimPlugins.nvim-dap-virtual-text ];

    keymaps = [
      {
        mode = "n";
        key = "<leader>du";
        action = ''
          function()
            local filetype = vim.bo.filetype
            if filetype == "dap-repl" or filetype:match("^dapui_") then
              require("dapui").close()
              return
            end

            require("dapui").open()
            local rank = {
              dapui_scopes = 1,
              dapui_breakpoints = 2,
              dapui_stacks = 3,
              dapui_watches = 4,
              ["dap-repl"] = 5,
              dapui_console = 6,
            }
            local target, best = nil, math.huge
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
              local win_filetype = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
              if rank[win_filetype] and rank[win_filetype] < best then
                target, best = win, rank[win_filetype]
              end
            end
            if target then
              vim.api.nvim_set_current_win(target)
            end
          end
        '';
        lua = true;
        desc = "Open or focus debugger panels";
      }
    ];

    luaConfigRC.nvim-dap-virtual-text = inputs.nvf.lib.nvim.dag.entryAfter [ "nvim-dap" ] ''
      require("nvim-dap-virtual-text").setup({
        commented = true,
        only_first_definition = true,
      })

      local dap_windows = vim.api.nvim_create_augroup("LuixDapWindows", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = dap_windows,
        pattern = {
          "dapui_scopes",
          "dapui_breakpoints",
          "dapui_stacks",
          "dapui_watches",
          "dap-repl",
          "dapui_console",
        },
        callback = function(args)
          vim.keymap.set("n", "q", function()
            require("dapui").close()
          end, {
            buffer = args.buf,
            desc = "Close debugger panels",
            silent = true,
          })
        end,
      })
    '';
  };
}
