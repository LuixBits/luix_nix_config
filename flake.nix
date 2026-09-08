{
  description = "Multi-host NixOS and Home Manager configuration";

  inputs = {
    # primary channels
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # home-manager
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Model-specific laptop support
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";

    # NVF (Neovim framework)
    nvf.url = "github:notashelf/nvf";
    nvf.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Noctalia shell (Wayland desktop shell + launcher)
    noctalia.url = "github:noctalia-dev/noctalia-shell";
    noctalia.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Star Citizen helper flake
    nix-citizen.url = "github:LovingMelody/nix-citizen";
    nix-citizen.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Herdr terminal workflow
    herdr.url = "github:herdrdev/herdr/v0.8.2";
    herdr.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Neorg flashcards plugin and NVF module
    luixbits-neorg-flashcards.url = "github:LuixBits/luixbits-neorg-flashcards.nvim?ref=v0.2.0";
    luixbits-neorg-flashcards.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Sentry plugin and NVF module
    luixbits-sentry.url = "github:LuixBits/luixbits-sentry.nvim";
    luixbits-sentry.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # RoomPlan plugin
    roomplan.url = "github:LuixBits/luixbits-roomplanner.nvim";
    roomplan.inputs.nixpkgs.follows = "nixpkgs";

    # Neotest adapter for Node's built-in test runner. This is kept as a raw
    # source input because it is not packaged in our pinned nixpkgs yet.
    neotest-nodejs = {
      url = "github:AkisArou/neotest-nodejs";
      flake = false;
    };

  };

  outputs =
    { nixpkgs, home-manager, ... }@inputs:
    let
      mkHost =
        {
          hostModule,
          homeHost,
          hmUser,
          machine,
          networkHostName,
        }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit
              inputs
              machine
              networkHostName
              ;
            primaryUser = hmUser;
          };

          modules = [
            hostModule
            {
              networking.hostName = networkHostName;
            }

            # Home-Manager as a NixOS module
            home-manager.nixosModules.home-manager
            {
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-back";
              home-manager.overwriteBackup = true;
              home-manager.extraSpecialArgs = {
                inherit
                  inputs
                  machine
                  networkHostName
                  ;
              };
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
          hostModule = ./hosts/pc;
          homeHost = ./home/hosts/pc.nix;
          hmUser = "luix";
          machine = "pc";
          networkHostName = "pc";
        };
        l = mkHost {
          hostModule = ./hosts/l;
          homeHost = ./home/hosts/l.nix;
          hmUser = "luix";
          machine = "l";
          networkHostName = "l";
        };

        framework = mkHost {
          hostModule = ./hosts/framework;
          homeHost = ./home/hosts/framework.nix;
          hmUser = "luiz";
          machine = "framework";
          networkHostName = "framework";
        };
      };
    };
}
