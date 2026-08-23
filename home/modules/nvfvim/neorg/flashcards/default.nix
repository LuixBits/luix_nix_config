{
  config,
  inputs,
  ...
}:
let
  notesDir = "${config.home.homeDirectory}/notes";
in
{
  imports = [
    inputs.luixbits-neorg-flashcards.homeManagerModules.nvf
  ];

  programs.nvf.neorg-flashcards = {
    enable = true;
    schemaPresets = {
      japanese = [ "japanese" ];
      computer_science = [ "question_answer" ];
    };
    setupOpts = {
      default_collection = "japanese";
      collections = {
        japanese = {
          label = "Japanese";
          path = "${notesDir}/japanese/flashcards";
          default_file = "cards.norg";
          default_card_type = "japanese";
        };
        computer_science = {
          label = "Computer Science";
          path = "${notesDir}/computer-science/flashcards";
          default_file = "cards.norg";
          default_card_type = "question_answer";
        };
      };
      ui.show_shortcuts = true;
    };
    keymaps = {
      enable = true;
      prefix = "<leader>nc";
    };
  };
}
