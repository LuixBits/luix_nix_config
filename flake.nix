{
  description = "Multi-host NixOS and Home Manager configuration";

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

    # Star Citizen helper flake
    nix-citizen.url = "github:LovingMelody/nix-citizen";
    nix-citizen.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Herdr terminal workflow
    herdr.url = "github:herdrdev/herdr/v0.9.0";
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
      packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          openLinkHub = pkgs.openlinkhub;
          openLinkHubRuntimePath = pkgs.lib.makeBinPath [
            pkgs.coreutils
            pkgs.pciutils
            pkgs.systemd
          ];
        in
        {
          pia-setup = pkgs.callPackage ./packages/pia-setup { };

          # Bring up cooling without realizing the complete NixOS closure. This
          # is intentionally transient; the declarative service replaces it on
          # the next full NixOS activation.
          openlinkhub-emergency = pkgs.writeShellApplication {
            name = "openlinkhub-emergency";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.sudo
              pkgs.systemd
            ];
            text = ''
              if [[ "''${1:-}" == "--help" || "''${1:-}" == "-h" ]]; then
                echo "Start a temporary OpenLinkHub service without rebuilding NixOS."
                echo "The service lasts until it is stopped or the machine reboots."
                exit 0
              fi

              if (( EUID != 0 )); then
                exec sudo -- "$0" "$@"
              fi

              if systemctl is-active --quiet openlinkhub.service; then
                echo "The permanent OpenLinkHub service is already running."
                exit 0
              fi

              if systemctl is-active --quiet openlinkhub-emergency.service; then
                echo "The temporary OpenLinkHub service is already running."
                echo "Web UI: http://127.0.0.1:27003/"
                exit 0
              fi

              state_dir=/run/openlinkhub-emergency
              application_root=${openLinkHub}/opt/OpenLinkHub

              install -d -m 0700 \
                "$state_dir/database" \
                "$state_dir/static" \
                "$state_dir/web"

              cp --recursive --no-clobber --no-preserve=mode,ownership \
                "$application_root/database/." "$state_dir/database/"
              cp --recursive --force --no-preserve=mode,ownership \
                "$application_root/static/." "$state_dir/static/"
              cp --recursive --force --no-preserve=mode,ownership \
                "$application_root/web/." "$state_dir/web/"
              chmod -R u+rwX,go-rwx "$state_dir"

              systemd-run \
                --unit=openlinkhub-emergency.service \
                --collect \
                --description="Temporary OpenLinkHub cooling controller" \
                --property=WorkingDirectory="$state_dir" \
                --property=Restart=on-failure \
                --property=RestartSec=5s \
                --property=UMask=0077 \
                --property=NoNewPrivileges=true \
                --property=ProtectHome=true \
                --property=ProtectSystem=strict \
                --property=ReadWritePaths="$state_dir" \
                --setenv=PATH=${openLinkHubRuntimePath} \
                ${openLinkHub}/bin/OpenLinkHub

              sleep 1
              if ! systemctl is-active --quiet openlinkhub-emergency.service; then
                journalctl --unit=openlinkhub-emergency.service --lines=50 --no-pager
                exit 1
              fi

              echo "Temporary OpenLinkHub service started."
              echo "Web UI: http://127.0.0.1:27003/"
              echo "Stop it with: sudo systemctl stop openlinkhub-emergency.service"
            '';
          };
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
