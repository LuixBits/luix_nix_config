{ config, pkgs, ... }:
{
  assertions = [
    {
      assertion = config.networking.hostName == "pc";
      message = "hosts/features/gaming.nix installs Star Citizen and must only be imported by the pc host.";
    }
  ];

  programs.steam.enable = true; # enables Steam and required 32-bit runtime
  programs.gamemode.enable = true;

  # LACT: GPU monitoring (temps, clocks, VRAM, power) plus fan-curve and
  # undervolt/overclock control for the 7900 XTX. GUI talks to the lactd
  # root daemon this option starts.
  services.lact.enable = true;

  # Gamescope: forces a game into an exact-resolution window, e.g. as a
  # Steam launch option `gamescope -W 2560 -H 1440 -- %command%` for
  # 16:9 recording on the ultrawide.
  programs.gamescope.enable = true;

  # vulkaninfo for checking which GPU the Vulkan drivers see.
  environment.systemPackages = [ pkgs.vulkan-tools ];

  # Star Citizen via the LUG-maintained flatpak launcher. Declarative through
  # nix-flatpak, whose NixOS module this host imports via the simracing module.
  # The launcher is not on Flathub; it ships from its own repo. Declaring
  # `remotes` replaces nix-flatpak's default list, so flathub (used by
  # Boxflat) must be listed here too.
  # Star Citizen's kernel limits (vm.max_map_count, fs.file-max) are set for
  # all hosts in hosts/common/base.nix.
  services.flatpak = {
    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
      {
        name = "RSILauncher";
        location = "https://mactan-sc.github.io/rsilauncher/RSILauncher.flatpakrepo";
      }
    ];
    packages = [
      {
        appId = "io.github.mactan_sc.RSILauncher";
        origin = "RSILauncher";
      }
    ];
  };

  hardware.graphics.enable32Bit = true;
}
