{
  config,
  inputs,
  lib,
  pkgs,
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
    package =
      inputs.luixbits-neorg-flashcards.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
        (old: {
          patches = (old.patches or [ ]) ++ [ ./review-keymaps.patch ];
        });
    languagePresets = [ "japanese" ];
    setupOpts = {
      flashcards_dir = flashcardsDir;
      default_file = defaultFile;
      default_kind = "japanese";
    };
    keymaps = {
      enable = true;
      prefix = "<leader>nc";
    };
  };

  programs.nvf.settings.vim.keymaps = [
    {
      mode = "n";
      key = "<leader>ncd";
      action = "<cmd>NeorgFlashcardReviewDue<CR>";
      desc = "Review due flashcards";
    }
    {
      mode = "n";
      key = "<leader>ncg";
      action = "<cmd>NeorgFlashcardOverview<CR>";
      desc = "Flashcard dashboard";
    }
    {
      mode = "n";
      key = "<leader>nca";
      action = "<cmd>NeorgFlashcardStats<CR>";
      desc = "Flashcard dashboard analytics";
    }
  ];
}
