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
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs-unstable";

    #nixcats for Lua-configured neovim
    nixCats.url         = "github:BirdeeHub/nixCats-nvim";
    nixCats.inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, nix-gaming, nix-citizen, nixCats, ... }@inputs: 
  let
    system = "x86_64-linux";
    hm = inputs.home-manager;
    pkgs = import nixpkgs { inherit system; };
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
    outputs = { nixpkgs, nixCats, ... }:
    nixCats.lib.makeOutputs {
      inherit nixpkgs;
      # Category definitions define plugin lists and other resources.
      categoryDefinitions = { pkgs, ... }: {
        startupPlugins.general = [
          pkgs.vimPlugins.telescope-nvim
          pkgs.vimPlugins.telescope-fzf-native-nvim
          pkgs.vimPlugins.nvim-web-devicons
          pkgs.vimPlugins.gitsigns-nvim
          pkgs.vimPlugins.lazygit-nvim
          pkgs.vimPlugins.indent-blankline-nvim
          pkgs.vimPlugins.lualine-nvim
          pkgs.vimPlugins.alpha-nvim        # dashboard replacement
          pkgs.vimPlugins.tokyonight-nvim
        ];
        # optionalPlugins could be used for lazy‑loaded plugins
        optionalPlugins.none = [];
        # LSPs and run‑time dependencies (executables) are specified here
        lspsAndRuntimeDeps.general = [
          pkgs.nodePackages.typescript-language-server
          pkgs.nodePackages.vls               # Vue language server (volar)
          pkgs.nodePackages.vscode-json-languageserver
          pkgs.nodePackages.vscode-css-languageserver-bin
          pkgs.lua-language-server
          pkgs.nixd
        ];
      };
      # Package definitions: map categories to package names and declare aliases.
      packageDefinitions = {
        nvimLuix = { pkgs, ... }: {
          # Provide an alias so you can run `nvim` to start this package
          settings = { aliases = [ "nvim" ]; };
          categories = {
            general = true;
          };
        };
      };
      # Name of the default package
      defaultPackageName = "nvimLuix";
    };
  };
}
