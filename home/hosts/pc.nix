{ inputs, pkgs, ... }:
let
  # The pinned Blender/ROCm packages otherwise collide through LLVM 19/22.
  # Keep the verified workaround local to Blender, never in the session env.
  # https://github.com/NixOS/nixpkgs/issues/530702
  blenderForVideo = pkgs.symlinkJoin {
    name = "blender-hip-video";
    paths = [ pkgs.pkgsRocm.blender ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/blender" \
        --prefix LD_PRELOAD : "${pkgs.rocmPackages.rocm-comgr}/lib/libamd_comgr.so.3"
    '';
    meta = pkgs.pkgsRocm.blender.meta;
  };
in
{
  home.username = "luix";
  home.homeDirectory = "/home/luix";

  imports = [
    ../common.nix
    inputs.spatial-input.homeManagerModules.default
    ../modules/spatial-input-development
    ../modules/simracing
    ../modules/prismlauncher
  ];

  luix.spatialInputDevelopment.enable = true;

  # SpaceMouse daemon at login, Niri and Herdr sessions registered by themselves.
  # The bindings live in the project checkout and reload with `spatialctl config reload`.
  services.spatial-input = {
    enable = true;
    configFile = "/home/luix/projects/spatial-input/config/examples/profiles.toml";
    configOwnership = "file";
    integrations.niri.enable = true;
    integrations.herdr.socket = "/home/luix/.config/herdr/sessions/herdr-luix/herdr.sock";
  };
  luix.simracing.enable = true;

  # Native Wayland corrupts Firefox's chrome texture cache on this GPU,
  # hiding tab titles, URL text, and bookmark labels. XWayland renders it correctly.
  home.sessionVariables.MOZ_ENABLE_WAYLAND = "0";

  home.packages = with pkgs; [
    protonup-qt
    # Star Citizen production: HIP rendering and the licensed Fusion/Fairlight suite.
    blenderForVideo
    davinci-resolve-studio
  ];
}
