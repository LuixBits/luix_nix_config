{
  config,
  inputs,
  lib,
  ...
}:
let
  notesDir = "${config.home.homeDirectory}/notes";
  flashcardsDir = "${notesDir}/japanese/flashcards";
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
    schemaPresets.japanese = [
      "japanese"
      "japanese_production"
      "japanese_kanji"
      "japanese_sentence"
    ];
    setupOpts = {
      default_collection = "japanese";
      collections.japanese = {
        label = "Japanese";
        path = flashcardsDir;
        default_file = "cards.norg";
        default_card_type = "japanese";
      };
      ui.show_shortcuts = true;
    };
    keymaps = {
      enable = true;
      prefix = "<leader>nc";
    };
  };
}
