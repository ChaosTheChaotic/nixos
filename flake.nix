{
  description = "NixOS Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
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
    vicinae.url = "github:vicinaehq/vicinae";
    f-sy-h = {
      url = "github:z-shell/F-Sy-H";
      flake = false;
    };
    clogite.url = "github:chaosthechaotic/clogite";
    tereix.url = "github:chaosthechaotic/tereix";
    lovely-injector.url = "git+https://github.com/ethangreen-dev/lovely-injector?submodules=1";
    mpd = {
      url = "github:MusicPlayerDaemon/MPD";
      flake = false;
    };
    millennium.url = "github:SteamClientHomebrew/Millennium?dir=packages/nix";
  };

  outputs =
    {
      nixpkgs,
      nixos-apple-silicon,
      home-manager,
      agenix,
      ...
    }@inputs:
    {
      nixosConfigurations = {
        "NixyPenguin" =
          let
            csys = "aarch64-linux";
          in
          nixpkgs.lib.nixosSystem {
            system = csys;
            specialArgs = { inherit inputs; };
            modules = [
              nixos-apple-silicon.nixosModules.apple-silicon-support
              ./hosts/NixyPenguin/default.nix
              agenix.nixosModules.default
              {
                environment.systemPackages = [ agenix.packages.${csys}.default ];
              }
              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.extraSpecialArgs = {
                  inherit inputs;
                  cpuArch = "apple-m1";
                };
                home-manager.users.chaos = import ./users/chaos/home.nix;
              }
            ];
          };
        "Nixpad" =
          let
            csys = "x86_64-linux";
          in
          nixpkgs.lib.nixosSystem {
            system = csys;
            specialArgs = { inherit inputs; };
            modules = [
              ./hosts/Nixpad/default.nix
              agenix.nixosModules.default
              {
                environment.systemPackages = [ agenix.packages.${csys}.default ];
              }
              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.extraSpecialArgs = {
                  inherit inputs;
                  cpuArch = "skylake";
                };
                home-manager.users.chaos = import ./users/chaos/home.nix;
              }
            ];
          };
      };
    };
}
