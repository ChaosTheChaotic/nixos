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
    tree-sitter.url = "github:tree-sitter/tree-sitter";
    ani-cli = {
      url = "github:pystardust/ani-cli/fix";
      flake = false;
    };
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
      nixosConfigurations =
        let
          mkHost =
            {
              hostName,
              system,
              cpuArch,
              extraModules ? [ ],
            }:
            nixpkgs.lib.nixosSystem {
              inherit system;
              specialArgs = {
                inherit inputs;
                wgHelper = import ./modules/wireguard.nix;
              };
              modules = [
                ./hosts/${hostName}/default.nix
                agenix.nixosModules.default
                { environment.systemPackages = [ agenix.packages.${system}.default ]; }
                home-manager.nixosModules.home-manager
                {
                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;
                  home-manager.extraSpecialArgs = { inherit inputs cpuArch; };
                  home-manager.users.chaos = import ./users/chaos/home.nix;
                }
              ]
              ++ extraModules;
            };
        in
        {
          "NixyPenguin" = mkHost {
            hostName = "NixyPenguin";
            system = "aarch64-linux";
            cpuArch = "apple-m1";
            extraModules = [ nixos-apple-silicon.nixosModules.apple-silicon-support ];
          };

          "Nixpad" = mkHost {
            hostName = "Nixpad";
            system = "x86_64-linux";
            cpuArch = "skylake";
          };
        };
    };
}
