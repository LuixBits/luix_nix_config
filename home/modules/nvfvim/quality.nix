{
  lib,
  pkgs,
  ...
}:
{
  programs.nvf.settings.vim = {
    formatter.conform-nvim = {
      enable = true;
      presets = {
        prettier = {
          enable = true;
          plugins = [ "svelte" ];
        };
        ruff.enable = true;
        php-cs-fixer.enable = true;
        qmlformat.enable = true;
        nixfmt.enable = true;
        stylua.enable = true;
        shfmt.enable = true;
        taplo.enable = true;
      };

      setupOpts = {
        # Formatting is deliberately manual. Linting still runs after save.
        format_on_save = null;
        format_after_save = null;
        default_format_opts = {
          lsp_format = "fallback";
          timeout_ms = 2000;
        };

        formatters_by_ft = {
          javascript = [ "prettier" ];
          javascriptreact = [ "prettier" ];
          typescript = [ "prettier" ];
          typescriptreact = [ "prettier" ];
          vue = [ "prettier" ];
          svelte = [ "prettier" ];
          html = [ "prettier" ];
          css = [ "prettier" ];
          scss = [ "prettier" ];
          json = [ "prettier" ];
          jsonc = [ "prettier" ];
          yaml = [ "prettier" ];
          dockercompose = [ "prettier" ];
          markdown = [ "prettier" ];

          php = [ "php-cs-fixer" ];
          python = [ "ruff" ];
          qml = [ "qmlformat" ];
          nix = [ "nixfmt" ];
          lua = [ "stylua" ];
          sh = [ "shfmt" ];
          bash = [ "shfmt" ];
          toml = [ "taplo" ];
          gdscript = [ "gdformat" ];
        };

        formatters = {
          # Conform already knows gdformat's arguments; pin only its executable.
          gdformat.command = lib.getExe' pkgs.gdtoolkit_4 "gdformat";

          # NVF's Ruff preset currently sends `format.indent-width`, which
          # Ruff 0.15 rejects because indent-width is a top-level setting.
          # Let each project's Ruff configuration (or Ruff's defaults) decide
          # indentation instead of injecting a broken command-line override.
          ruff = {
            args = lib.mkForce [
              "format"
              "--force-exclude"
              "--stdin-filename"
              "$FILENAME"
              "-"
            ];
            range_args = lib.mkForce (
              lib.generators.mkLuaInline ''
                function(self, ctx)
                  return {
                    "format",
                    "--force-exclude",
                    "--range", string.format(
                      "%d:%d-%d:%d",
                      ctx.range.start[1],
                      ctx.range.start[2] + 1,
                      ctx.range["end"][1],
                      ctx.range["end"][2] + 1
                    ),
                    "--stdin-filename", "$FILENAME",
                    "-",
                  }
                end
              ''
            );
          };
        };
      };
    };

    diagnostics = {
      presets = {
        eslint_d.enable = true;
        phpstan.enable = true;
        shellcheck.enable = true;
        hadolint.enable = true;
        markdownlint-cli2.enable = true;
      };

      nvim-lint = {
        enable = true;
        lint_after_save = true;
        linters_by_ft = {
          javascript = [ "eslint_d" ];
          javascriptreact = [ "eslint_d" ];
          typescript = [ "eslint_d" ];
          typescriptreact = [ "eslint_d" ];
          vue = [ "eslint_d" ];
          svelte = [ "eslint_d" ];
          php = [ "phpstan" ];
          sh = [ "shellcheck" ];
          bash = [ "shellcheck" ];
          dockerfile = [ "hadolint" ];
          markdown = [ "markdownlint-cli2" ];
          gdscript = [ "gdlint" ];
        };

        # nvim-lint ships the gdlint parser; this supplies the Nix executable.
        linters.gdlint.cmd = lib.getExe' pkgs.gdtoolkit_4 "gdlint";
      };
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>lf";
        action = "<cmd>lua require('conform').format({ async = true, lsp_format = 'fallback' })<CR>";
        desc = "Format buffer";
      }
      {
        mode = "n";
        key = "<leader>ll";
        action = "<cmd>lua nvf_lint(vim.api.nvim_get_current_buf())<CR>";
        desc = "Lint buffer";
      }
    ];
  };
}
