{ ... }:
{
  home.username = "luiz";
  home.homeDirectory = "/home/luiz";

  imports = [
    ../common.nix
    ../modules/virt-manager
    ../modules/work
  ];
}
