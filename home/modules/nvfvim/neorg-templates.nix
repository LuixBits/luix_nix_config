{
  config,
  lib,
  pkgs,
  ...
}: let
  notesDir = "${config.home.homeDirectory}/notes";
  templatesDir = "${notesDir}/templates";
  starterTemplatesDir = ./neorg-templates;
  neorgTemplateEngine = pkgs.vimUtils.buildVimPlugin {
    pname = "neorg-template-engine.nvim";
    version = "0.1.0";
    src = ./neorg-template-engine-plugin;
  };

  starterTemplateFiles =
    lib.filterAttrs
    (name: type: type == "regular" && lib.hasSuffix ".norg" name)
    (builtins.readDir starterTemplatesDir);

  seedTemplates = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: _: ''
        if [ ! -e "${templatesDir}/${name}" ]; then
          run install -m 0644 "${starterTemplatesDir + "/${name}"}" "${templatesDir}/${name}"
        fi
      ''
    )
    starterTemplateFiles
  );
in {
  home.activation.ensureNeorgWorkspace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "${notesDir}" "${templatesDir}"
    ${seedTemplates}
  '';

  programs.nvf.settings.vim = {
    startPlugins = [
      neorgTemplateEngine
    ];

    luaConfigRC.neorg-template-engine = ''
      require("neorg_template_engine").setup({
        notes_dir = vim.fn.expand(${builtins.toJSON notesDir}),
        templates_dir = vim.fn.expand(${builtins.toJSON templatesDir}),
        author = ${builtins.toJSON config.home.username},
      })
    '';
  };
}
