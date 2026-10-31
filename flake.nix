{
  description = "NixOS Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-pinned-kernel.url = "github:NixOS/nixpkgs/d407951447dcd00442e97087bf374aad70c04cea";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixos-apple-silicon.url = "github:nix-community/nixos-apple-silicon/3902c801519264191a7c3dfec8dd1f9faeb38fd5"; # TODO: Check and remove lock on this and pinned kernel once binary cache is back
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
    vicinae-extensions = {
      url = "github:vicinaehq/extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    tree-sitter.url = "path:./pkgs/tree-sitter";
    ani-cli = {
      url = "github:pystardust/ani-cli";
      flake = false;
    };
    steam-asahi = {
      url = "github:sm-idk/steam-asahi";
      inputs.nixpkgs.follows = "nixpkgs-master";
    };
    bcon = {
      url = "github:sanohiro/bcon";
      flake = false;
    };
    stylix.url = "github:nix-community/stylix";
    fbb.url = "github:ChaosTheChaotic/framebuffer-browser";
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
    equi.url = "path:./users/chaos/equi/plugins";
    balatro.url = "path:./users/chaos/balatro";
  };

  outputs =
    {
      nixpkgs,
      nixos-apple-silicon,
      home-manager,
      agenix,
      steam-asahi,
      vicinae,
      stylix,
      nix-flatpak,
      fbb,
      clogite,
      ...
    }@inputs:
    {
      nixosConfigurations =
        let
          userName = "chaos";
          consts = import ./modules/consts.nix { homeDir = "/home/${userName}"; };
          mkHost =
            {
              hostName,
              system,
              cpuArch,
              stateVersion,
              wg ? null, # { secretName, publicKey, endpoint }
              syncthing ? null, # { secretName } — cert at ./hosts/${hostName}/syncthing-cert.pem
              extraModules ? [ ],
              systemExtraSpecialArgs ? { },
            }:
            let
              sharedArgs = {
                inherit inputs cpuArch consts userName;
                arch = import ./lib/arch.nix {
                  inherit (nixpkgs) lib;
                  inherit cpuArch;
                  isAarch64 = system == "aarch64-linux";
                };
              };

              hostDefaults =
                { config, lib, ... }:
                let
                  wgHelper = import ./modules/wireguard.nix;
                in
                lib.mkMerge [
                  {
                    networking.hostName = hostName;
                    system.stateVersion = stateVersion;
                  }
                  (lib.mkIf (wg != null) {
                    age.secrets.${wg.secretName}.file = ./secrets/${wg.secretName}.age;
                    networking.wg-quick.interfaces = wgHelper.mkWgInterface {
                      privateKeyPath = config.age.secrets.${wg.secretName}.path;
                      publicKey = wg.publicKey;
                      endpoint = wg.endpoint;
                    };
                  })
                  (lib.mkIf (syncthing != null) {
                    age.secrets.syncthing-key.file = ./secrets/${syncthing.secretName}.age;
                    services.syncthing.cert = ./hosts/${hostName}/syncthing-cert.pem;
                  })
                ];
            in
            nixpkgs.lib.nixosSystem {
              inherit system;
              specialArgs =
                sharedArgs // { wgHelper = import ./modules/wireguard.nix; } // systemExtraSpecialArgs;
              modules = [
                ./hosts/common.nix
                ./hosts/${hostName}/default.nix
                ./hosts/${hostName}/hardware-configuration.nix
                hostDefaults
                agenix.nixosModules.default
                stylix.nixosModules.stylix
                fbb.nixosModules.default
                nix-flatpak.nixosModules.nix-flatpak
                { environment.systemPackages = [ agenix.packages.${system}.default ]; }
                home-manager.nixosModules.home-manager
                {
                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;
                  home-manager.extraSpecialArgs = sharedArgs;
                  home-manager.sharedModules = [
                    vicinae.homeManagerModules.default
                    clogite.homeManagerModules.default
                  ];
                  home-manager.users.${userName} = import ./users/${userName}/home.nix;
                }
              ]
              ++ extraModules;
            };
        in
        {
          "Nixpad" = mkHost {
            hostName = "Nixpad";
            system = "x86_64-linux";
            cpuArch = "skylake";
            stateVersion = "26.05";
            wg = {
              secretName = "wg-priv-thinker";
              publicKey = "JB84ctFi3l+gxJxr/kwYXlKwLcmqWxuuLBkpE1anmgo=";
              endpoint = "195.242.214.194:51820";
            };
            syncthing = {
              secretName = "syncthing-key-thinker";
            };
          };

          "NixyPenguin" = mkHost {
            hostName = "NixyPenguin";
            system = "aarch64-linux";
            cpuArch = "apple-m1";
            stateVersion = "25.11";
            wg = {
              secretName = "wg-priv-asahi";
              publicKey = "KiCvg9+bh7/ssQDALW3uXSTLaURS3mgZdi/O9CxlFXo=";
              endpoint = "79.127.254.65:51820";
            };
            syncthing = {
              secretName = "syncthing-key-asahi";
            };
            extraModules = [
              nixos-apple-silicon.nixosModules.apple-silicon-support
              steam-asahi.nixosModules.default
            ];
            systemExtraSpecialArgs = { inherit (inputs) nixpkgs-pinned-kernel; };
          };
        };
    };
}
