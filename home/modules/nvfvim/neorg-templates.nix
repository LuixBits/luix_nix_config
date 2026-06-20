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

  listTemplateFiles =
    dir:
    lib.flatten (
      lib.mapAttrsToList (
        name: type:
        let
          path = dir + "/${name}";
        in
        if type == "directory" then
          map (nested: "${name}/${nested}") (listTemplateFiles path)
        else if type == "regular" && lib.hasSuffix ".norg" name then
          [ name ]
        else
          [ ]
      ) (builtins.readDir dir)
    );

  starterTemplateFiles = listTemplateFiles starterTemplatesDir;

  seedTemplates = lib.concatStringsSep "\n" (
    map (
      relativePath: ''
        if [ ! -e "${templatesDir}/${relativePath}" ]; then
          run mkdir -p "$(dirname "${templatesDir}/${relativePath}")"
          run install -m 0644 "${starterTemplatesDir + "/${relativePath}"}" "${templatesDir}/${relativePath}"
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
        workspace = "notes",
        author = ${builtins.toJSON config.home.username},
      })
    '';
  };
}
