# Install the setup command and launcher; saved VPN credentials stay on disk.
{ pkgs, ... }:
{
  environment.systemPackages = [
    (pkgs.callPackage ../../packages/pia-setup { })
  ];
}
