{ config, lib, pkgs, ... }:
let
  python = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);
  claudeStatusline = pkgs.writeShellScriptBin "claude-statusline" ''
    exec ${pkgs.python3}/bin/python3 ${./claude_statusline.py}
  '';
  kimiStatusline = pkgs.writeShellScriptBin "kimi-statusline" ''
    exec ${pkgs.python3}/bin/python3 ${./kimi_statusline.py} "$@"
  '';
in
{
  home.packages = [ claudeStatusline kimiStatusline ];

  # The CLIs and Herdr modify their settings. Merge the managed statusline
  # and question shortcut fields instead of using read-only store symlinks.
  home.activation.ensureAgentStatuslines = lib.hm.dag.entryAfter [
    "ensureCodexConfig"
    "ensureHerdrAgentIntegrations"
  ] ''
    run ${python}/bin/python3 ${./configure_statuslines.py} \
      ${lib.escapeShellArg "${config.programs.claude-code.configDir}/settings.json"} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/.codex/config.toml"} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/.kimi-code/tui.toml"} \
      ${lib.escapeShellArg "${claudeStatusline}/bin/claude-statusline"} \
      ${lib.escapeShellArg "${kimiStatusline}/bin/kimi-statusline"}
  '';

  # Kimi Code gives custom footer commands only 300 ms. Keep quotas cached by
  # a background fetcher so the synchronous statusline render stays fast.
  systemd.user.services.kimi-statusline-refresh = {
    Unit = {
      Description = "Refresh Kimi Code quota cache for the status line";
      After = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${kimiStatusline}/bin/kimi-statusline --fetch-quotas";
    };
  };

  systemd.user.timers.kimi-statusline-refresh = {
    Unit.Description = "Keep Kimi Code quota cache fresh";
    Timer = {
      OnBootSec = "30";
      OnUnitActiveSec = "30";
      Persistent = true;
      Unit = "kimi-statusline-refresh.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
