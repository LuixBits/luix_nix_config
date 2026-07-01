{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  notesDir = "${config.home.homeDirectory}/notes";
  flashcardsDir = "${notesDir}/japanese/flashcards";
  defaultFile = "${flashcardsDir}/cards.norg";
  neorgFlashcards = pkgs.vimUtils.buildVimPlugin {
    pname = "luixbits-neorg-flashcards.nvim";
    version = "0.1.0";
    src = inputs.luixbits-neorg-flashcards;
  };
in {
  home.activation.ensureNeorgFlashcards = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "${flashcardsDir}"
  '';

  programs.nvf.settings.vim = {
    startPlugins = [
      neorgFlashcards
    ];

    binds.whichKey.register."<leader>nc" = "+Cards";

    keymaps = [
      {
        mode = "n";
        key = "<leader>nco";
        action = "<cmd>NeorgFlashcardOpen<CR>";
        desc = "Open Japanese flashcards";
      }
      {
        mode = "n";
        key = "<leader>nci";
        action = "<cmd>NeorgFlashcardAdd<CR>";
        desc = "Add flashcard";
      }
      {
        mode = "n";
        key = "<leader>nch";
        action = "<cmd>NeorgFlashcardHelp<CR>";
        desc = "Flashcard help";
      }
      {
        mode = "n";
        key = "<leader>ncr";
        action = "<cmd>NeorgFlashcardReview<CR>";
        desc = "Review flashcards";
      }
      {
        mode = "n";
        key = "<leader>ncf";
        action = "<cmd>NeorgFlashcardReviewFile<CR>";
        desc = "Review file flashcards";
      }
      {
        mode = "n";
        key = "<leader>nct";
        action = "<cmd>NeorgFlashcardReviewTag<CR>";
        desc = "Review tag flashcards";
      }
      {
        mode = "n";
        key = "<leader>ncs";
        action = "<cmd>NeorgFlashcardReviewScore<CR>";
        desc = "Review score flashcards";
      }
      {
        mode = "n";
        key = "<leader>ncv";
        action = "<cmd>NeorgFlashcardValidate<CR>";
        desc = "Validate flashcards";
      }
    ];

    luaConfigRC.neorg-flashcards = ''
      local presets = require("neorg_flashcards.presets")

      require("neorg_flashcards").setup({
        flashcards_dir = vim.fn.expand(${builtins.toJSON flashcardsDir}),
        default_file = vim.fn.expand(${builtins.toJSON defaultFile}),
        default_kind = "japanese",
        languages = presets.only("japanese"),
      })
    '';
  };
}
