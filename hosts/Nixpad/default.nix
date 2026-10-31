{
  pkgs,
  inputs,
  ...
}:

{
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

  services.flatpak.packages = [ "org.vinegarhq.Sober" ];

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
}
