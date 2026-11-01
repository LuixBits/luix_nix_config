{ config, lib, pkgs, inputs, ... }:
let
  notesDir = "${config.home.homeDirectory}/notes";
  packages = import ./packages.nix { inherit pkgs; };
  pluginBackup = "${config.xdg.stateHome}/notes-plugins/legacy";
in
{
  home.packages = [ packages.youtubeNotesCli ];
  programs.nvf.settings.vim = {
    extraPackages = [ pkgs.git ];
    startPlugins = [ packages.neorgView packages.youtubeNotes ];
    luaConfigRC.portable-notes = inputs.nvf.lib.nvim.dag.entryAfter [ "mappings" "pluginConfigs" "lazyConfigs" ] ''
      -- Suppress the old local bootstrap if it survives until activation cleanup.
      vim.g.loaded_luix_youtube_notes = true
      require("neorg_view").setup({
        journal = true,
        sync = {
          command = { ${builtins.toJSON config.luix.notesSync.commands.sync} },
          service_root = ${builtins.toJSON notesDir},
        },
      })
      require("luix_youtube").setup({
        notes_root = ${builtins.toJSON notesDir},
        repo_root = ${builtins.toJSON notesDir},
        backend = { ${builtins.toJSON "${packages.youtubeNotesCli}/bin/youtube-notes"} },
      })
    '';
  };

  # Only retire the two exact symlinks from the earlier manual installation.
  # Preserve the links as a rollback aid and leave unrelated user files alone.
  home.activation.retireLocalNotesPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    retire_notes_link() {
      local link="$1" expected="$2" backup
      if [ -L "$link" ] && [ "$(readlink -- "$link")" = "$expected" ]; then
        run mkdir -p ${lib.escapeShellArg pluginBackup}
        backup=${lib.escapeShellArg pluginBackup}/"$(basename "$link").$(date +%s%N)"
        run mv -- "$link" "$backup"
      fi
    }
    retire_notes_link ${lib.escapeShellArg "${config.xdg.configHome}/nvf/plugin/luix-neorg-view.lua"} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/projects/neorg-view.nvim/integration/nvf.lua"}
    retire_notes_link ${lib.escapeShellArg "${config.xdg.configHome}/nvf/plugin/luix-youtube-notes.lua"} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/projects/LuixBitsRemotion/nvim/youtube-notes/plugin/youtube-notes.lua"}
    unset -f retire_notes_link
  '';
}
