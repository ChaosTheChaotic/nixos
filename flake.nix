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
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-apple-silicon,
      home-manager,
      nur,
      ...
    }@inputs:
    {
      nixosConfigurations."NixyPenguin" = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
	specialArgs = { inherit inputs ;};
        modules = [
          nixos-apple-silicon.nixosModules.apple-silicon-support
          ./configuration.nix
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
