{
  config,
  pkgs,
  inputs,
  ...
}:

let
  customPkgs = import ../pkgs/default.nix { inherit pkgs; };
  extraFonts = pkgs.callPackage ../pkgs/fonts.nix {
    stdenvNoCC = pkgs.stdenvNoCC;
    lib = pkgs.lib;
    findutils = pkgs.findutils;
  };
in
{

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
    inputs.rose-pine-hyprcursor.packages.${pkgs.stdenv.hostPlatform.system}.default
    android-tools
    xdg-desktop-portal-termfilechooser
    inotify-tools
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

  nixpkgs.config.allowUnfree = true;

  age.secrets.gh-pat.file = ../secrets/gh-pat.age;
  nix.extraOptions = ''
    !include ${config.age.secrets.gh-pat.path}
  '';

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    system-features = [
      "big-parallel"
      "benchmark"
    ];
    flake-registry = "";
  };

  nix.optimise = {
    automatic = true;
    dates = [ "15:15" ];
  };

  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

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
  boot.kernelParams = [
    "zswap.enabled=1"
    "zswap.compressor=zstd"
    "zswap.zpool=zsmalloc"
    "zswap.max_pool_percent=25"
  ];

  systemd.settings.Manager = {
    DefaultTimeoutStartSec = "90s";
  };

  system.autoUpgrade.enable = false;
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
    "116.202.176.26"
  ];
  networking.networkmanager.dns = "none";
  services.zerotierone = {
    enable = true;
    joinNetworks = [ "8d1c312afa2aad91" ];
  };

  services.upower = {
    enable = true;
  };

  #services.kmscon = {
  #  enable = true;
  #  hwRender = true;
  #  config = {
  #    font-name = "JetBrainsMono Nerd Font Mono";
  #  };
  #};

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
  security.pam.loginLimits = [
    {
      domain = "@users";
      item = "nofile";
      type = "soft";
      value = "1048576";
    }
    {
      domain = "@users";
      item = "nofile";
      type = "hard";
      value = "1048576";
    }
  ];
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
      "render"
      "input"
      "seat"
      "kvm"
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
    libraries = with pkgs; [
      zlib
      openssl
      stdenv.cc.cc.lib
    ];
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
      xdg-desktop-portal-termfilechooser
    ];
    config = {
      common = {
        default = [
          "hyprland"
          "gtk"
        ];
        "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
      };
    };
  };

  systemd.user.services.xdg-desktop-portal-termfilechooser = {
    environment = {
      XDG_CONFIG_HOME = "/etc/xdg"; # Just read from /etc/xdg instead of ~/.config
    }
    // import ../modules/consts.nix { homeDir = config.users.users.chaos.home; };
    path = with pkgs; [
      inotify-tools
      coreutils
      gawk
      "/run/current-system/sw"
      "/etc/profiles/per-user/chaos"
    ];
  };

  environment.etc."xdg/xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd = ${customPkgs.scripts}/bin/_termfp.sh
    default_dir = /tmp
  '';

  programs.kdeconnect.enable = true;

  environment.variables = {
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
    C_INCLUDE_PATH = "${pkgs.openssl.dev}/include";
    XDG_DATA_DIRS = [
      "${pkgs.hyprland}/share"
    ];
  }
  // import ../modules/consts.nix { homeDir = config.users.users.chaos.home; };

  documentation = {
    enable = true;
    man.enable = true;
  };
}
