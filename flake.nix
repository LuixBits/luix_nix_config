{
  description = "Fixed flake for NixOS + home-manager + NVF";

  inputs = {
    # primary channels
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # gaming/other overlays
    nix-gaming.url = "github:fufexan/nix-gaming";

    # Star Citizen flake
    nix-citizen.url = "github:LovingMelody/nix-citizen";
    nix-citizen.inputs.nix-gaming.follows = "nix-gaming";

    # home-manager
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # NVF (Neovim framework)
    nvf.url = "github:notashelf/nvf";
    nvf.inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, nix-gaming, nix-citizen, nvf, ... }@inputs:
  {
    # NixOS configuration
    nixosConfigurations.pc = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };

      modules = [
        ./configuration.nix
        ./hosts/pc

        # Home-Manager as a NixOS module
        home-manager.nixosModules.home-manager
        {
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-back";
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.luix = import ./home/luix;
        }
      ];
    };

    nixosConfigurations.l = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };

      modules = [
        ./configuration.nix
        ./hosts/l

        # Home-Manager as a NixOS module
        home-manager.nixosModules.home-manager
        {
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-back";
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.luix = import ./home/luix;
        }
      ];
    };
  };
}
