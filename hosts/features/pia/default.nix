# Install the setup command and launcher; saved VPN credentials stay on disk.
{ pkgs, ... }:
{
  environment.systemPackages = [
    (pkgs.callPackage ./package.nix { })
  ];

  # wg-quick owns the interface used by the manual `pia` command.
  networking.networkmanager.unmanaged = [ "interface-name:pia-manual" ];
}
