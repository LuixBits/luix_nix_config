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

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, nvf, ... }@inputs:
  {
    # NixOS configuration
    nixosConfigurations.pc = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };

      modules = [
        ./hosts/pc

        # Home-Manager as a NixOS module
        home-manager.nixosModules.home-manager
        {
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-back";
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.luix = import ./home/hosts/pc.nix;
        }
      ];
    };

    nixosConfigurations.l = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };

      modules = [
        ./hosts/l

        # Home-Manager as a NixOS module
        home-manager.nixosModules.home-manager
        {
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-back";
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.luix = import ./home/hosts/l.nix;
        }
      ];
    };
  };
}
