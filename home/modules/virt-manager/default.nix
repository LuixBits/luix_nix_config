{ pkgs, ... }:
{
  home.packages = with pkgs; [
    virt-manager
    virt-viewer
  ];

  dconf.settings."org/virt-manager/virt-manager/connections" = {
    autoconnect = [ "qemu:///system" ];
    uris = [ "qemu:///system" ];
  };
}
