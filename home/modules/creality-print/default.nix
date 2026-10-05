{ inputs, pkgs, ... }:
let
  version = "7.2.1";
  sha256 = "9cad8cc96081beffefb054220cdd7d2c9516f39a108f7c08063f17ebc70f65c7";
  bundle = pkgs.fetchurl {
    url = "https://github.com/CrealityOfficial/CrealityPrint/releases/download/v${version}/CrealityPrint-Linux-flatpak_V${version}-Release_x86_64.flatpak";
    inherit sha256;
  };
in
{
  imports = [ inputs.nix-flatpak.homeManagerModules.nix-flatpak ];

  services.flatpak = {
    enable = true;
    uninstallUnmanaged = false;
    packages = [
      {
        appId = "io.github.crealityofficial.CrealityPrint";
        bundle = "${bundle}";
        # nix-flatpak also uses this hash to detect bundle upgrades.
        inherit sha256;
      }
    ];
  };
}
