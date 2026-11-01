{ pkgs }:
let
  neorgView = pkgs.vimUtils.buildVimPlugin {
    pname = "neorg-view.nvim";
    version = "0.2.0";
    src = ./sources/neorg-view.nvim;
  };
  youtubeNotes = pkgs.vimUtils.buildVimPlugin {
    pname = "youtube-notes.nvim";
    version = "0.2.0";
    src = ./sources/youtube-notes.nvim;
  };
  youtubeNotesCli = pkgs.writeShellApplication {
    name = "youtube-notes";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      export YOUTUBE_NOTES_PORTABLE=1
      exec node ${youtubeNotes}/scripts/youtube-notes.mjs "$@"
    '';
  };
in { inherit neorgView youtubeNotes youtubeNotesCli; }
