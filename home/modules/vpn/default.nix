# Home Manager: Proton VPN GUI only
{ pkgs, ... }:
{
  home.packages = [
    pkgs.protonvpn-gui
  ];
}

