{
  config,
  pkgs,
  lib,
  inputs,
  wgHelper,
  nixpkgs-pinned-kernel,
  ...
}:

let
  millennium-bin = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "millennium-bin";
    version = "3.6.1";
    src = pkgs.fetchurl {
      url = "https://github.com/SteamClientHomebrew/Millennium/releases/download/v${finalAttrs.version}/millennium-v${finalAttrs.version}-linux-x86_64.tar.gz";
      sha256 = "sha256-AhWhl3mtkopTxelHdzBjaSrUCrWheboRlobeUVD7t2M=";
    };
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/usr/lib/millennium
      tar -xzf $src -C $out
      chmod -R a+rX $out/usr/lib/millennium
    '';
  });
in
{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
  ];

  nixpkgs.overlays = [
    (final: prev: {
      uboot-asahi = prev.uboot-asahi.overrideAttrs (old: {
        makeFlags = (old.makeFlags or [ ]) ++ [
          "DTC=${final.buildPackages.dtc}/bin/dtc"
        ];
      });
    })
  ];

  boot.kernelPackages = lib.mkForce (
    let
      pinnedPkgs = import nixpkgs-pinned-kernel {
        system = "aarch64-linux";
        config.allowUnfree = true;
        overlays = [
          inputs.nixos-apple-silicon.overlays.apple-silicon-overlay
          (final: prev: {
            uboot-asahi = prev.uboot-asahi.overrideAttrs (old: {
              makeFlags = (old.makeFlags or [ ]) ++ [
                "DTC=${final.buildPackages.dtc}/bin/dtc"
              ];
            });
          })
        ];
      };
    in
    pinnedPkgs.linux-asahi
  );

  environment = {
    systemPackages = with pkgs; [
      asahi-bless
      asahi-btsync
      asahi-wifisync
      (muvm.override {
        fex = (
          pkgs.fex.overrideAttrs (oldAttrs: {
            nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [
              pkgs.python3Packages.packaging
              pkgs.python3Packages.setuptools
            ];
          })
        );
      })
      (callPackage ../../pkgs/naev/naev.nix { scalefactorPatch = true; })
      #nvimpager
    ];

    sessionVariables = {
      BTRY_DEV = "macsmc-battery";
    };
  };

  programs.steam-asahi = {
    enable = true;

    package = pkgs.steam-asahi.override {
      extraEnv = (pkgs.steam-asahi.extraEnv or { }) // {
        MILLENNIUM_RUNTIME_PATH = "${millennium-bin}/usr/lib/millennium/libmillennium_x86.so";
      };
    };
  };

  systemd.user.tmpfiles.rules = [
    "L+ %h/.local/share/Steam/ubuntu12_32/libXtst.so.6 - - - - ${millennium-bin}/usr/lib/millennium/libmillennium_bootstrap_x86.so"
    "L+ %h/.local/share/Steam/ubuntu12_64/libXtst.so.6 - - - - ${millennium-bin}/usr/lib/millennium/libmillennium_bootstrap_hhx64.so"
  ];

  nix.settings = {
    extra-substituters = [
      "https://nixos-apple-silicon.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="
    ];
    system-features = [
      "gccarch-apple-m1"
    ];
    flake-registry = "";
  };

  hardware.asahi = {
    enable = true;
    peripheralFirmwareDirectory = ../../firmware;
    setupAsahiSound = true;
  };

  boot.loader.efi.canTouchEfiVariables = false;

  networking.hostName = "NixyPenguin";

  age.secrets.wg-priv-asahi.file = ../../secrets/wg-priv-asahi.age;

  age.secrets.syncthing-key.file = ../../secrets/syncthing-key-asahi.age;
  services.syncthing.cert = "${./syncthing-cert.pem}";

  networking.wg-quick.interfaces = wgHelper.mkWgInterface {
    privateKeyPath = config.age.secrets.wg-priv-asahi.path;
    publicKey = "KiCvg9+bh7/ssQDALW3uXSTLaURS3mgZdi/O9CxlFXo=";
    endpoint = "79.127.254.65:51820";
  };

  system.stateVersion = "25.11";
}
