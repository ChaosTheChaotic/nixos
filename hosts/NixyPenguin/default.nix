{
  config,
  pkgs,
  wgHelper,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
  ];

  environment.systemPackages = with pkgs; [
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

  programs.steam-asahi = {
    enable = true;
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

  networking.wg-quick.interfaces = wgHelper.mkWgInterface {
    privateKeyPath = config.age.secrets.wg-priv-asahi.path;
    publicKey = "KiCvg9+bh7/ssQDALW3uXSTLaURS3mgZdi/O9CxlFXo=";
    endpoint = "79.127.254.65:51820";
  };

  system.stateVersion = "25.11";
}
