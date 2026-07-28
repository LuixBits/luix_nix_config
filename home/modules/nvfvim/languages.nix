{
  lib,
  pkgs,
  ...
}:
let
  grammars = pkgs.vimPlugins.nvim-treesitter.grammarPlugins;
in
{
  programs.nvf.settings.vim = {
    lsp = {
      enable = true;
      formatOnSave = false;

      # Godot owns the GDScript language server. It accepts editor
      # connections while a project is open in Godot.
      servers.gdscript = {
        enable = true;
        cmd = lib.generators.mkLuaInline ''
          vim.lsp.rpc.connect("127.0.0.1", 6005)
        '';
        filetypes = [ "gdscript" ];
        root_markers = [
          "project.godot"
          ".git"
        ];
      };

      # These Luau files are general Luau rather than Roblox/Rojo projects.
      servers."luau-lsp" = {
        enable = true;
        cmd = [
          (lib.getExe pkgs.luau-lsp)
          "lsp"
        ];
        filetypes = [ "luau" ];
        root_markers = [
          ".luaurc"
          "default.project.json"
          ".git"
        ];
      };
    };

    languages = {
      enableTreesitter = true;

      # Formatting and extra linting are selected centrally in quality.nix.
      # In particular, this prevents NVF's Vue module from selecting Biome.
      enableFormat = false;
      enableExtraDiagnostics = false;
      enableDAP = false;

      php = {
        enable = true;
        lsp.servers = [ "intelephense" ];
      };

      # The TypeScript module also covers JavaScript.
      typescript.enable = true;
      tsx.enable = true;
      vue = {
        enable = true;
        lsp.servers = [
          "vue-language-server"
          "vtsls"
        ];
      };
      svelte.enable = true;

      twig.enable = true;
      html.enable = true;
      css.enable = true;
      scss.enable = true;
      json.enable = true;
      yaml.enable = true;
      xml.enable = true;
      toml.enable = true;
      sql.enable = true;

      bash.enable = true;
      fish.enable = true;
      docker.enable = true;

      python = {
        enable = true;
        # basedpyright supplies types/navigation; Ruff supplies fast linting.
        lsp.servers = [
          "basedpyright"
          "ruff"
        ];
      };

      qml.enable = true;

      lua = {
        enable = true;
        lsp.lazydev.enable = true;
      };

      nix = {
        enable = true;
        lsp.servers = [ "nixd" ];
      };

      markdown.enable = true;
    };

    filetype = {
      filename."project.godot" = "gdresource";
      extension = {
        tscn = "gdresource";
        tres = "gdresource";
      };
    };

    treesitter = {
      grammars = [
        grammars.gdscript
        grammars.gdshader
        grammars.godot_resource
        grammars.luau
      ];

      filetypeMappings.godot_resource = [ "gdresource" ];
    };

    # Also makes gdformat and gdlint available from Neovim's terminal.
    extraPackages = [ pkgs.gdtoolkit_4 ];
  };
}
