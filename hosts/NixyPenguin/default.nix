{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  customPkgs = pkgs.callPackage ../../pkgs/default.nix { };
  extraFonts = pkgs.callPackage ../../pkgs/fonts.nix { };
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  environment.systemPackages = with pkgs; [
    customPkgs.scripts
    customPkgs.scriptsManPgs
    git
    openssl.dev
    man-pages
    man-pages-posix
    brightnessctl
    pamixer
    bluez
    bluetui
    unp
    cmake
    ffmpeg
    wireguard-tools
    usbutils
    glib-networking
    gdb
    gnupg
    ncdu
    vlc
    chafa
    xxd
    go
    ccache
    inputs.lobster.packages.${pkgs.stdenv.hostPlatform.system}.lobster
    inputs.rose-pine-hyprcursor.packages.${pkgs.stdenv.hostPlatform.system}.default
    android-tools
    asahi-bless
    asahi-btsync
    asahi-wifisync
    muvm
    #nvimpager
  ];

  fonts.packages = [
    extraFonts
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.nerd-fonts.fira-code
    pkgs.nerd-fonts.fira-mono
  ];

  nixpkgs.overlays = [
    inputs.nur.overlays.default
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    extra-substituters = [
      "https://nixos-apple-silicon.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="
    ];
  };

  nix.optimise = {
    automatic = true;
    dates = [ "15:15" ];
  };

  hardware.asahi = {
    peripheralFirmwareDirectory = ../../firmware;
    setupAsahiSound = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
        FastConnectable = false;
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.kernelParams = [
    "zswap.enabled=1"
    "zswap.compressor=zstd"
    "zswap.zpool=zsmalloc"
    "zswap.max_pool_percent=25"
  ];

  systemd.settings.Manager = {
    DefaultTimeoutStartSec = "15s";
  };

  system.autoUpgrade.enable = false;
  networking.hostName = "NixyPenguin";

  networking.wireless.iwd = {
    enable = true;
    settings.General.EnableNetworkConfiguration = true;
  };
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.backend = "iwd";
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
    "9.9.9.9"
  ];
  networking.networkmanager.dns = "none";

  age.secrets.wg-priv.file = ../../secrets/wg-priv.age;

  networking.wg-quick.interfaces = {
    wg0 = {
      address = [ "10.2.0.2/32" ];
      dns = [
        "1.1.1.1"
        "8.8.8.8"
        "9.9.9.9"
        "10.2.0.1"
      ];
      privateKeyFile = config.age.secrets.wg-priv.path;
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

  services.zerotierone = {
    enable = true;
    joinNetworks = [ "8d1c312afa2aad91" ];
  };

  services.upower = {
    enable = true;
  };

  services.kmscon = {
    enable = true;
    hwRender = true;
    fonts = [
      {
        name = "JetBrainsMono Nerd Font Mono";
        package = pkgs.nerd-fonts.jetbrains-mono;
      }
      {
        name = "FiraCode Nerd Font Mono";
        package = pkgs.nerd-fonts.fira-code;
      }
    ];
  };

  hardware.enableRedistributableFirmware = true;
  time.timeZone = "Europe/London";

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = true;
  };

  security.rtkit.enable = true;
  services.flatpak.enable = true;
  services.openssh.enable = true;

  programs.zsh.enable = true;
  environment.shells = with pkgs; [ zsh ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  users.users.chaos = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "adbusers"
      "video"
      "input"
    ];
    shell = pkgs.zsh;
  };

  programs.java.enable = true;

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  programs.nix-ld = {
    enable = true;
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-hyprland ];
  };

  programs.kdeconnect.enable = true;

  environment.variables = {
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
    C_INCLUDE_PATH = "${pkgs.openssl.dev}/include";
    XDG_DATA_DIRS = [
      "${pkgs.hyprland}/share"
    ];
  };

  documentation = {
    enable = true;
    man.enable = true;
  };

  system.stateVersion = "25.11";
}
