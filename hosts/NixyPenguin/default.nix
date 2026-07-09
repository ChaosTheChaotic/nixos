{
  config,
  pkgs,
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
    muvm
    #nvimpager
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

  networking.wg-quick.interfaces = {
    wg0 = {
      address = [ "10.2.0.2/32" ];
      dns = [
        "1.1.1.1"
        "8.8.8.8"
        "9.9.9.9"
        "116.202.176.26"
        "10.2.0.1"
      ];
      privateKeyFile = config.age.secrets.wg-priv-asahi.path;
      peers = [
        {
          publicKey = "KiCvg9+bh7/ssQDALW3uXSTLaURS3mgZdi/O9CxlFXo=";
          allowedIPs = [
            "0.0.0.0/0"
            "::/0"
          ];
          endpoint = "79.127.254.65:51820";
        }
      ];
    };
  };

  system.stateVersion = "25.11";
}
