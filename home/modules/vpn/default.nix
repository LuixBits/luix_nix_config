# Home Manager: Proton VPN GUI only
{ pkgs, ... }:
{
  home.packages = [
    pkgs.proton-vpn
  ];
}
