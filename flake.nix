{
  description = "Fixed flake for NixOS + home-manager + NVF";

  inputs = {
    # primary channels
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # home-manager
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # NVF (Neovim framework)
    nvf.url = "github:notashelf/nvf";
    nvf.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Noctalia shell (Wayland desktop shell + launcher)
    noctalia.url = "github:noctalia-dev/noctalia-shell";
    noctalia.inputs.nixpkgs.follows = "nixpkgs-unstable";

  };

  outputs = { nixpkgs, home-manager, ... }@inputs:
    let
      mkHost =
        {
          hostName,
          homeHost,
          hmUser,
        }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };

          modules = [
            ./hosts/${hostName}

            # Home-Manager as a NixOS module
            home-manager.nixosModules.home-manager
            {
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-back";
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users = {
                "${hmUser}" = import homeHost;
              };
            }
          ];
        };
    in
    {
      nixosConfigurations = {
        pc = mkHost {
          hostName = "pc";
          homeHost = ./home/hosts/pc.nix;
          hmUser = "luix";
        };
        l = mkHost {
          hostName = "l";
          homeHost = ./home/hosts/l.nix;
          hmUser = "luix";
        };
        work = mkHost {
          hostName = "work";
          homeHost = ./home/hosts/work.nix;
          hmUser = "luiz";
        };
      };
    };
}
