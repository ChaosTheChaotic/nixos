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

  environment = {
    systemPackages = with pkgs; [
      age
      age-plugin-tpm
    ];

    sessionVariables = {
      BTRY_DEV = "BAT1";
    };
  };

  age.identityPaths = [
    "${./Nixpad-tpm.key}"
  ];

  age.ageBin = "${pkgs.writeShellScriptBin "age-tpm" ''
    export PATH="${pkgs.age-plugin-tpm}/bin:$PATH"
    exec ${pkgs.age}/bin/age "$@"
  ''}/bin/age-tpm";

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

  networking = {
    hostName = "Nixpad";
    wg-quick.interfaces = wgHelper.mkWgInterface {
      privateKeyPath = config.age.secrets.wg-priv-thinker.path;
      publicKey = "JB84ctFi3l+gxJxr/kwYXlKwLcmqWxuuLBkpE1anmgo=";
      endpoint = "195.242.214.194:51820";
    };
  };

  age.secrets.wg-priv-thinker.file = ../../secrets/wg-priv-thinker.age;

  programs.steam = {
    enable = true;
    package = pkgs.millennium-steam;

    protontricks.enable = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  hardware.graphics.enable32Bit = true;

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  system.stateVersion = "26.05";
}
