{ config, inputs, ... }:
{
  home.username = "luiz";
  home.homeDirectory = "/home/luiz";

  imports = [
    ../common.nix
    inputs.spatial-input.homeManagerModules.default
    ../modules/virt-manager
    ../modules/work
  ];

  services.spatial-input = {
    enable = true;
    # Ship the profiles and their relative icons with the pinned remote source.
    configFile = "${inputs.spatial-input}/config/examples/profiles.toml";
    configOwnership = "declarative";
    integrations.niri.enable = true;
    integrations.herdr.socket = "${config.xdg.configHome}/herdr/sessions/herdr-luix/herdr.sock";
  };
}
