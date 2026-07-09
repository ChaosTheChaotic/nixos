{
  config,
  pkgs,
  inputs,
  wgHelper,
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

  networking.wg-quick.interfaces = wgHelper.mkWgInterface {
    privateKeyPath = config.age.secrets.wg-priv-thinker.path;
    publicKey = "jB84ctFi3l+gxJxr/kwYXlKwLcmqWxuuLBkpE1anmgo=";
    endpoint = "195.242.214.194:51820";
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
