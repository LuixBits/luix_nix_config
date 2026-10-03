{
  description = "Multi-host NixOS and Home Manager configuration";

  # Make the AI package cache available during the first rebuild as well.
  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  inputs = {
    # primary channels
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # home-manager
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Declarative installation of selected Flathub applications.
    nix-flatpak.url = "github:gmodena/nix-flatpak/v0.7.0";

    # Model-specific laptop support
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";

    # NVF (Neovim framework)
    nvf.url = "github:notashelf/nvf";
    nvf.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Noctalia shell (Wayland desktop shell + launcher)
    noctalia.url = "github:noctalia-dev/noctalia-shell";
    noctalia.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Daily updates for Codex, Claude Code, and Herdr. Keep the provider's own
    # nixpkgs so packages match its tested builds and binary cache.
    llm-agents.url = "github:numtide/llm-agents.nix";

    # Neorg flashcards plugin and NVF module
    luixbits-neorg-flashcards.url = "github:LuixBits/luixbits-neorg-flashcards.nvim";
    luixbits-neorg-flashcards.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Sentry plugin and NVF module
    luixbits-sentry.url = "github:LuixBits/luixbits-sentry.nvim";
    luixbits-sentry.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # RoomPlan plugin
    roomplan.url = "github:LuixBits/luixbits-roomplanner.nvim";
    roomplan.inputs.nixpkgs.follows = "nixpkgs";

    # Spatial Input: SpaceMouse daemon, udev rules, Niri/Herdr registration.
    # Local checkout until the repository is published.
    spatial-input.url = "git+file:///home/luix/projects/spatial-input";
    spatial-input.inputs.nixpkgs.follows = "nixpkgs";

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
      packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          pia-setup = pkgs.callPackage ./hosts/features/pia/package.nix { };

          # Transient cooling bring-up for the pc without a full rebuild.
          openlinkhub-emergency = pkgs.callPackage ./hosts/features/corsair-cooling/emergency.nix { };
        }
      );

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

        # Bootable LuixBits capture VM: the l config on virtual hardware,
        # rebuildable from inside the VM for on-camera nixos-rebuild demos.
        l-capture = mkHost {
          hostModule = ./hosts/l/capture.nix;
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
