{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
  ];

  nixpkgs.overlays = [
    inputs.millennium.overlays.default
  ];

  nix.settings = {
    system-features = [
      "gccarch-skylake"
    ];
  };

  boot.loader.efi.canTouchEfiVariables = true;

  systemd.settings.Manager = {
    DefaultTimeoutStopSec = "10s";
  };

  networking.hostName = "Nixpad";

  age.secrets.wg-priv-thinker.file = ../../secrets/wg-priv-thinker.age;
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
      privateKeyFile = config.age.secrets.wg-priv-thinker.path;
      peers = [
        {
          publicKey = "JB84ctFi3l+gxJxr/kwYXlKwLcmqWxuuLBkpE1anmgo=";
          allowedIPs = [
            "0.0.0.0/0"
            "::/0"
          ];
          endpoint = "195.242.214.194:51820";
        }
      ];
    };
  };

  programs.steam = {
    enable = true;
    package = pkgs.millennium-steam;

    protontricks.enable = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  hardware.graphics.enable32Bit = true;

  system.stateVersion = "26.05";
}
