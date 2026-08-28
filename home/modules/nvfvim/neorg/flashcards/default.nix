{
  config,
  inputs,
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

  programs.nvf.neorg-flashcards = {
    enable = true;
    # v0.2 is the newest published, portable release. The former named
    # Computer Science collection used an unpublished local v0.3 checkout;
    # restore it only together with that source and an explicit card migration.
    schemaPresets = [ "japanese" ];
    setupOpts = {
      flashcards_dir = flashcardsDir;
      default_file = "${flashcardsDir}/cards.norg";
      default_kind = "japanese";
      ui.show_shortcuts = true;
    };
    keymaps = {
      enable = true;
      prefix = "<leader>nc";
    };
  };
}
