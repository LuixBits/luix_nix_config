{
  config,
  inputs,
  lib,
  ...
}:
let
  notesDir = "${config.home.homeDirectory}/notes";
  flashcardsDir = "${notesDir}/japanese/flashcards";
  defaultFile = "${flashcardsDir}/cards.norg";
in
{
  imports = [
    inputs.luixbits-neorg-flashcards.homeManagerModules.nvf
  ];

  home.activation.ensureNeorgFlashcards = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "${flashcardsDir}"
  '';

  programs.nvf.neorg-flashcards = {
    enable = true;
    schemaPresets = [ "japanese" ];
    setupOpts = {
      flashcards_dir = flashcardsDir;
      default_file = defaultFile;
      default_kind = "japanese";
      ui.show_shortcuts = true;
    };
    keymaps = {
      enable = true;
      prefix = "<leader>nc";
    };
  };
}
