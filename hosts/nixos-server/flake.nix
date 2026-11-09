{
  description = "Luix server at 192.168.18.26";

  # Match the server's installed release while introducing declarative management.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/c56a87d8e41ce69bd2af57eb35dcc117a9dfca33";

  outputs = { nixpkgs, ... }: {
    nixosConfigurations.nixos-server = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./default.nix ];
    };
  };
}
