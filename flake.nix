{
  description = "NixOS Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-apple-silicon.url = "github:nix-community/nixos-apple-silicon";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix.url = "github:ryantm/agenix";
    rose-pine-hyprcursor = {
      url = "github:ndom91/rose-pine-hyprcursor";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    inputs.lobster.url = "github:justchokingaround/lobster";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-apple-silicon,
      home-manager,
      nur,
      agenix,
      rose-pine-hyprcursor,
      lobster,
      ...
    }@inputs:
    let
      csys = "aarch64-linux";
    in
    {
      nixosConfigurations."NixyPenguin" = nixpkgs.lib.nixosSystem {
        system = csys;
        specialArgs = { inherit inputs; };
        modules = [
          nixos-apple-silicon.nixosModules.apple-silicon-support
          ./configuration.nix
          agenix.nixosModules.default
          {
            environment.systemPackages = [ agenix.packages.${csys}.default ];
          }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.chaos = ./home.nix;
          }
        ];
      };
    };
}
