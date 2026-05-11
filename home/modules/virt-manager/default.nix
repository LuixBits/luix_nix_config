{ pkgs, ... }:
{
  home.packages = with pkgs; [
    spice-gtk
    virt-manager
    virt-viewer
  ];

  dconf.settings."org/virt-manager/virt-manager/connections" = {
    autoconnect = [ "qemu:///system" ];
    uris = [ "qemu:///system" ];
  };

  dconf.settings."org/virt-manager/virt-manager/console" = {
    autoconnect = true;
    resize-guest = 1;
  };

  dconf.settings."org/virt-manager/virt-manager/new-vm" = {
    graphics-type = "spice";
  };
}
