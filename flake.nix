{
  description = "Fixed flake for NixOS + home-manager + nixCats-nvim";

  inputs = {
    # primary channels
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # pinned for davinci-resolve-studio
    nixpkgs-davinci.url = "github:NixOS/nixpkgs/e6f23dc08d3624daab7094b701aa3954923c6bbb";

    # gaming/other overlays
    nix-gaming.url = "github:fufexan/nix-gaming";

    # Star Citizen flake
    nix-citizen.url = "github:LovingMelody/nix-citizen";
    nix-citizen.inputs.nix-gaming.follows = "nix-gaming";

    # home-manager
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # neovim wrappers
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # nixCats-nvim
    nixCats.url = "github:BirdeeHub/nixCats-nvim";

    # NVF (Neovim framework)
    nvf.url = "github:notashelf/nvf";
    nvf.inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, nixCats, nix-gaming, nix-citizen, nixvim, nvf, ... }@inputs:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    nixCatsUtils = nixCats.utils;
    nixCatsCategoryDefinitions = { pkgs, ... }: {
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
      optionalPlugins.none = [];
      lspsAndRuntimeDeps.general = [
        pkgs.nodePackages.typescript-language-server
        pkgs.nodePackages.vls               # Vue language server (volar)
        pkgs.nodePackages.vscode-json-languageserver
        pkgs.nodePackages.vscode-css-languageserver-bin
        pkgs.lua-language-server
        pkgs.nixd
      ];
    };
    nixCatsPackageDefinitions = {
      nvimLuix = { pkgs, ... }: {
        # Provide an alias so you can run `nvim` to start this package
        settings = { aliases = [ "nvim" ]; };
        categories = {
          general = true;
        };
      };
    };
    nixCatsDefaultPackageName = "nvimLuix";
    nixCatsBuilder = nixCatsUtils.baseBuilder ./home/modules/lua {
      inherit nixpkgs system;
    } nixCatsCategoryDefinitions nixCatsPackageDefinitions;
    nixCatsDefaultPackage = nixCatsBuilder nixCatsDefaultPackageName;
    nixCatsOutputs = {
      packages.${system} = nixCatsUtils.mkAllWithDefault nixCatsDefaultPackage;
    };
  in
  {
    # NixOS configuration
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };

      modules = [
        ./configuration.nix

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
  } // nixCatsOutputs;
}
