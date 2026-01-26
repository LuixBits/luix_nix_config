{ inputs, pkgs, ... }:
let
  killMako = pkgs.writeShellScript "noctalia-kill-mako" ''
    ${pkgs.procps}/bin/pkill -x mako 2>/dev/null || true
  '';
in
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;
  };

  systemd.user.services.noctalia-shell.Service.ExecStartPre = [
    killMako
  ];
}
