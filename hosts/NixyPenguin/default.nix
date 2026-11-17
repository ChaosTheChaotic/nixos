{
  pkgs,
  lib,
  inputs,
  nixpkgs-pinned-kernel,
  ccache,
  ...
}:

let
  ubootAsahiFix = final: prev: {
    uboot-asahi = prev.uboot-asahi.overrideAttrs (old: {
      makeFlags = (old.makeFlags or [ ]) ++ [ "DTC=${final.buildPackages.dtc}/bin/dtc" ];
    });
  };
in
{
  nixpkgs.overlays = [
    ubootAsahiFix
  ];

  boot.kernelPackages = lib.mkForce (
    let
      pinnedPkgs = import nixpkgs-pinned-kernel {
        system = "aarch64-linux";
        config.allowUnfree = true;
        overlays = [
          ccache.overlay
          inputs.nixos-apple-silicon.overlays.apple-silicon-overlay
          ubootAsahiFix
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
        fex = ccache.withCmakeLauncher pkgs (
          pkgs.fex.overrideAttrs (oldAttrs: {
            nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [
              pkgs.python3Packages.setuptools
            ];
          })
        );
      })
      (callPackage ../../pkgs/naev/naev.nix {
        scalefactorPatch = true;
        stdenv = ccache.stdenv pkgs;
      })
      #nvimpager
    ];

    sessionVariables = {
      BTRY_DEV = "macsmc-battery";
    };
  };

	# steam-asahi module needs the gtk problem handler set to not abort as it does naturally
  programs.steam-asahi.enable = true;
  nixpkgs.config.problems.handlers = {
    "gtk+".broken = "warn";
  };

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
  };

  hardware.asahi = {
    enable = true;
    peripheralFirmwareDirectory = ../../firmware;
    setupAsahiSound = true;
  };

  boot.loader.efi.canTouchEfiVariables = false;
}
