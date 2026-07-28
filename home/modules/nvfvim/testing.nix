{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  neotest-nodejs = pkgs.vimUtils.buildVimPlugin {
    pname = "neotest-nodejs";
    version = "unstable";
    src = inputs.neotest-nodejs;
    dependencies = with pkgs.vimPlugins; [
      neotest
      nvim-nio
      plenary-nvim
    ];

    # This upstream test helper expects luassert/say globals and is not a
    # runtime module. Keep the Nix require-check on for everything else.
    nvimSkipModules = [ "neotest-nodejs-assertions" ];
  };
in
{
  programs.nvf.settings.vim = {
    startPlugins = with pkgs.vimPlugins; [
      neotest
      nvim-nio
      plenary-nvim
      neotest-phpunit
      neotest-python
      neotest-nodejs
    ];

    luaConfigRC.neotest =
      inputs.nvf.lib.nvim.dag.entryAfter
        [
          "pluginConfigs"
          "nvim-dap"
          "neotest-adapter-aliases"
        ]
        ''
          require("neotest").setup({
            adapters = {
              require("neotest-phpunit")({
                root_files = { "composer.json", "phpunit.xml", "phpunit.xml.dist" },
                filter_dirs = { ".git", "node_modules", "vendor", "var" },
              }),
              require("neotest-python")({
                dap = { justMyCode = false },
              }),
              require("neotest-nodejs")({
                nodeCommand = "${lib.getExe pkgs.nodejs}",
                nodeArguments = function(default_args)
                  local root = vim.fs.root(0, {
                    "pnpm-lock.yaml",
                    "package-lock.json",
                    "yarn.lock",
                    "bun.lockb",
                  }) or vim.fn.getcwd()

                  if vim.fn.isdirectory(root .. "/node_modules/tsx") == 1 then
                    return vim.list_extend({ "--import", "tsx" }, default_args)
                  end

                  return default_args
                end,
              }),
            },
            consumers = {
              luix_run_all = function(client)
                return {
                  run = require("nio").create(function()
                    local adapters = client:get_adapters()

                    if #adapters == 0 then
                      require("neotest.lib").notify(
                        "No test adapter found for this project",
                        vim.log.levels.WARN
                      )
                      return
                    end

                    table.sort(adapters)
                    local adapter = require("nio").ui.select(adapters, {
                      prompt = "Test adapter:",
                    })

                    if adapter then
                      require("neotest").run.run({ suite = true, adapter = adapter })
                    end
                  end),
                }
              end,
            },
          })
        '';

    keymaps = [
      {
        mode = "n";
        key = "<leader>tn";
        action = "<cmd>lua require('neotest').run.run()<CR>";
        desc = "Test nearest";
      }
      {
        mode = "n";
        key = "<leader>tf";
        action = "<cmd>lua require('neotest').run.run(vim.fn.expand('%'))<CR>";
        desc = "Test current file";
      }
      {
        mode = "n";
        key = "<leader>ta";
        action = "<cmd>lua require('neotest').luix_run_all.run()<CR>";
        desc = "Test all with chosen adapter";
      }
      {
        mode = "n";
        key = "<leader>td";
        action = "<cmd>lua require('neotest').run.run({ strategy = 'dap' })<CR>";
        desc = "Debug nearest test";
      }
      {
        mode = "n";
        key = "<leader>tr";
        action = "<cmd>lua require('neotest').run.run_last()<CR>";
        desc = "Repeat last test";
      }
      {
        mode = "n";
        key = "<leader>to";
        action = "<cmd>lua require('neotest').output.open({ enter = true })<CR>";
        desc = "Test output";
      }
      {
        mode = "n";
        key = "<leader>tp";
        action = "<cmd>lua require('neotest').output_panel.toggle()<CR>";
        desc = "Toggle test output panel";
      }
      {
        mode = "n";
        key = "<leader>ts";
        action = "<cmd>lua require('neotest').summary.toggle()<CR>";
        desc = "Toggle test summary";
      }
      {
        mode = "n";
        key = "<leader>tw";
        action = "<cmd>lua require('neotest').watch.toggle()<CR>";
        desc = "Watch nearest test";
      }
      {
        mode = "n";
        key = "<leader>tx";
        action = "<cmd>lua require('neotest').run.stop()<CR>";
        desc = "Stop test";
      }
    ];
  };
}
