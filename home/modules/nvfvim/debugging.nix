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
        stepOver = "<leader>dn";
        stepBack = "<leader>dp";
        goUp = "<leader>dk";
        goDown = "<leader>dj";
        toggleDapUI = "<leader>du";
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

    luaConfigRC.nvim-dap-virtual-text = inputs.nvf.lib.nvim.dag.entryAfter [ "nvim-dap" ] ''
      require("nvim-dap-virtual-text").setup({
        commented = true,
        only_first_definition = true,
      })
    '';
  };
}
