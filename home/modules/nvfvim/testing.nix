{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  pythonWithPytest = pkgs.python3.withPackages (pythonPackages: [ pythonPackages.pytest ]);

  neotest-fixed = pkgs.vimPlugins.neotest.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./neotest-nvf-subprocess.patch ];
  });

  neotest-nodejs = pkgs.vimUtils.buildVimPlugin {
    pname = "neotest-nodejs";
    version = "unstable";
    src = inputs.neotest-nodejs;
    dependencies = with pkgs.vimPlugins; [
      neotest-fixed
      nvim-nio
      plenary-nvim
    ];

    # This upstream test helper expects luassert/say globals and is not a
    # runtime module. Keep the Nix require-check on for everything else.
    nvimSkipModules = [ "neotest-nodejs-assertions" ];
  };
in
{
  xdg.configFile."nvf/lua/luix/neotest_phpunit.lua".source =
    ./lua/luix/neotest_phpunit.lua;

  programs.nvf.settings.vim = {
    startPlugins = [
      neotest-fixed
      pkgs.vimPlugins.nvim-nio
      pkgs.vimPlugins.plenary-nvim
      pkgs.vimPlugins.neotest-phpunit
      pkgs.vimPlugins.neotest-python
      pkgs.vimPlugins.neotest-vitest
      pkgs.vimPlugins.overseer-nvim
      neotest-nodejs
    ];

    luaConfigRC.overseer = inputs.nvf.lib.nvim.dag.entryAfter [ "pluginConfigs" ] ''
      require("overseer").setup({
        task_list = {
          direction = "bottom",
          min_height = 10,
          max_height = 20,
          keymaps = {
            ["<Esc>"] = { "<CMD>close<CR>", desc = "Close task list" },
          },
        },
        form = { border = "rounded" },
        task_win = { border = "rounded" },
        component_aliases = {
          -- Neotest tasks are ephemeral and disappear when Neovim exits. Keep
          -- them for the current session so successful output does not vanish
          -- before it can be inspected.
          default_neotest = {
            "on_exit_set_status",
            "on_complete_notify",
          },
        },
      })
    '';

    luaConfigRC.neotest =
      inputs.nvf.lib.nvim.dag.entryAfter
        [
          "pluginConfigs"
          "nvim-dap"
          "neotest-adapter-aliases"
          "overseer"
        ]
        ''
          -- Neotest checks nvim-nio with pcall(), which the lazy module loader
          -- cannot see. Load it explicitly before Neotest starts.
          local nio = require("nio")
          local neotest = require("neotest")

          local phpunit_adapter = require("luix.neotest_phpunit").wrap(
            require("neotest-phpunit")({
              root_files = {
                "composer.json",
                "phpunit.xml",
                "phpunit.xml.dist",
              },
              filter_dirs = { ".git", "node_modules", "vendor", "var" },
            })
          )

          neotest.setup({
            adapters = {
              phpunit_adapter,
              require("neotest-python")({
                dap = { justMyCode = false },
                runner = "pytest",
                python = function(root)
                  local candidates = {
                    root .. "/.venv/bin/python",
                    root .. "/venv/bin/python",
                  }
                  if vim.env.VIRTUAL_ENV then
                    table.insert(candidates, 1, vim.env.VIRTUAL_ENV .. "/bin/python")
                  end
                  for _, candidate in ipairs(candidates) do
                    if candidate and vim.fn.executable(candidate) == 1 then
                      return candidate
                    end
                  end
                  return "${lib.getExe pythonWithPytest}"
                end,
              }),
              require("neotest-vitest")({
                filter_dir = function(name)
                  return not vim.tbl_contains({
                    ".git",
                    "build",
                    "coverage",
                    "dist",
                    "node_modules",
                  }, name)
                end,
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
              -- This is Overseer's supported Neotest integration. Test runs
              -- gain a durable task/output view while Neotest remains the
              -- source of discovery, inline status, and diagnostics.
              overseer = require("neotest.consumers.overseer"),
              luix_run_all = function(client)
                return {
                  run = nio.create(function()
                    local adapters = client:get_adapters()
                    local preferred_by_filetype = {
                      php = { "neotest-phpunit" },
                      python = { "neotest-python" },
                      javascript = { "neotest-vitest", "neotest-nodejs" },
                      javascriptreact = { "neotest-vitest", "neotest-nodejs" },
                      typescript = { "neotest-vitest", "neotest-nodejs" },
                      typescriptreact = { "neotest-vitest", "neotest-nodejs" },
                      vue = { "neotest-vitest" },
                    }
                    local preferred = preferred_by_filetype[vim.bo.filetype]

                    if #adapters == 0 then
                      require("neotest.lib").notify(
                        preferred and preferred[1] == "neotest-vitest"
                            and "No Vitest tests found. Add and configure Vitest in this package first."
                          or "No test adapter found for this project",
                        vim.log.levels.WARN
                      )
                      return
                    end

                    table.sort(adapters)

                    local adapter

                    if preferred then
                      for _, candidate in ipairs(preferred) do
                        for _, adapter_id in ipairs(adapters) do
                          if vim.startswith(adapter_id, candidate .. ":") then
                            adapter = adapter_id
                            break
                          end
                        end
                        if adapter then
                          break
                        end
                      end

                      if not adapter then
                        require("neotest.lib").notify(
                          preferred[1] == "neotest-vitest"
                              and "No Vitest tests found. Add and configure Vitest in this package first."
                            or "No " .. preferred[1] .. " project found for this buffer.",
                          vim.log.levels.WARN
                        )
                        return
                      end
                    elseif #adapters == 1 then
                      adapter = adapters[1]
                    else
                      adapter = nio.ui.select(adapters, {
                        prompt = "Test adapter:",
                      })
                    end

                    if adapter then
                      neotest.run.run({ suite = true, adapter = adapter })
                    end
                  end),
                }
              end,
            },
            diagnostic = {
              enabled = true,
              severity = vim.diagnostic.severity.ERROR,
            },
            status = {
              signs = true,
              virtual_text = true,
            },
            summary = {
              count = true,
              follow = true,
              expand_errors = true,
              open = "botright vsplit | vertical resize 50",
              mappings = {
                -- A tree behaves like every other tree: h/l close/open,
                -- j/k move, and Enter jumps to the selected test.
                expand = "l",
                parent = "h",
                jumpto = "<CR>",
              },
            },
            output = {
              open_on_run = false,
            },
            output_panel = {
              open = "botright split | resize 18",
            },
          })

          local test_windows = vim.api.nvim_create_augroup("LuixTestWindows", { clear = true })
          vim.api.nvim_create_autocmd("FileType", {
            group = test_windows,
            pattern = {
              "neotest-summary",
              "neotest-output",
              "neotest-output-panel",
              "OverseerList",
              "OverseerOutput",
            },
            callback = function(args)
              local function close_test_window()
                local filetype = vim.bo[args.buf].filetype
                if filetype == "neotest-summary" then
                  neotest.summary.close()
                elseif filetype == "neotest-output-panel" then
                  neotest.output_panel.close()
                elseif filetype == "OverseerList" then
                  require("overseer").close()
                else
                  pcall(vim.api.nvim_win_close, 0, true)
                end
              end

              vim.keymap.set("n", "q", close_test_window, {
                buffer = args.buf,
                desc = "Close test window",
                silent = true,
              })
              vim.keymap.set("n", "<Esc>", close_test_window, {
                buffer = args.buf,
                desc = "Close test window",
                silent = true,
              })
            end,
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
        desc = "Test all for current language";
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
        action = ''
          function()
            local overseer = require("overseer")
            local tasks = overseer.list_tasks({
              include_ephemeral = true,
              filter = function(task)
                return task.metadata.neotest_group_id ~= nil
              end,
            })
            local task = tasks[1]
            if not task then
              vim.notify("No test output yet", vim.log.levels.INFO)
              return
            end

            local buffer = task:get_bufnr()
            local window = buffer and vim.fn.bufwinid(buffer) or -1
            if window ~= -1 then
              vim.api.nvim_set_current_win(window)
            else
              task:open_output("horizontal")
              vim.cmd("resize 18")
            end
          end
        '';
        lua = true;
        desc = "Open latest test output";
      }
      {
        mode = "n";
        key = "<leader>ts";
        action = ''
          function()
            local summary_buffer = vim.fn.bufnr("Neotest Summary")
            local summary_window = summary_buffer >= 0 and vim.fn.bufwinid(summary_buffer) or -1
            if summary_window ~= -1 then
              vim.api.nvim_set_current_win(summary_window)
            else
              require("neotest").summary.open({ enter = true })
            end
          end
        '';
        lua = true;
        desc = "Open or focus test explorer";
      }
      {
        mode = "n";
        key = "<leader>tt";
        action = "<cmd>OverseerToggle bottom<CR>";
        desc = "Toggle test task history";
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
