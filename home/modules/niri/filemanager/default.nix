{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nautilus
  ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = "org.gnome.Nautilus.desktop";
      "application/x-gnome-saved-search" = "org.gnome.Nautilus.desktop";
    };
  };
}
