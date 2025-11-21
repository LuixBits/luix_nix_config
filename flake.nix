{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-gaming.url = "github:fufexan/nix-gaming";
    # Star Citizen flake
    nix-citizen.url = "github:LovingMelody/nix-citizen";
    nix-citizen.inputs.nix-gaming.follows = "nix-gaming";

    # home manager
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # nixvim for Neovim configuration
    # pinned because newer nixvim revs currently expect `valueMeta` support in the
    # module system, which 25.05 doesn't provide yet.
    nixvim.url = "github:nix-community/nixvim/f4b9a7122425c56d65466fcafb99053730b2646a";
    nixvim.inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, nix-gaming, nix-citizen, ... }@inputs: 
  let
    system = "x86_64-linux";
    hm = inputs.home-manager;
  in  {
    # name matches your host ('nixos') so nixos-rebuild finds it automatically
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [ 
        ./configuration.nix 
        
	#Home Manager as a NixOS module
	hm.nixosModules.home-manager
	{
	  home-manager.useUserPackages = true;
 	  home-manager.users.luix = import ./home/luix;
	  home-manager.extraSpecialArgs = { inherit inputs; };
	  home-manager.backupFileExtension = "hm-back";
	}
      ];
    };
  };
}
