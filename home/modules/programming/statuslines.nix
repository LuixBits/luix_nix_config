{ config, lib, pkgs, ... }:
let
  python = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);
  claudeStatusline = pkgs.writeShellScriptBin "claude-statusline" ''
    exec ${pkgs.python3}/bin/python3 ${./claude_statusline.py}
  '';
in
{
  home.packages = [ claudeStatusline ];

  # Both CLIs and Herdr modify their settings. Merge the managed statusline
  # and question shortcut fields instead of using read-only store symlinks.
  home.activation.ensureAgentStatuslines = lib.hm.dag.entryAfter [
    "ensureCodexConfig"
    "ensureHerdrAgentIntegrations"
  ] ''
    run ${python}/bin/python3 ${./configure_statuslines.py} \
      ${lib.escapeShellArg "${config.programs.claude-code.configDir}/settings.json"} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/.codex/config.toml"} \
      ${lib.escapeShellArg "${claudeStatusline}/bin/claude-statusline"}
  '';
}
