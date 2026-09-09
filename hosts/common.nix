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

  environment = {
    systemPackages = with pkgs; [
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
    shells = with pkgs; [ zsh ];
    sessionVariables.NIXOS_OZONE_WL = "1";
    variables = {
      PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
      C_INCLUDE_PATH = "${pkgs.openssl.dev}/include";
      XDG_DATA_DIRS = [
        "${pkgs.hyprland}/share"
      ];
    }
    // import ../modules/consts.nix { homeDir = config.users.users.chaos.home; };
    etc."xdg/xdg-desktop-portal-termfilechooser/config".text = ''
      [filechooser]
      cmd = ${customPkgs.scripts}/bin/_termfp.sh
      default_dir = /tmp
    '';
  };

  fonts.packages = [
    extraFonts
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.nerd-fonts.fira-code
    pkgs.nerd-fonts.fira-mono
  ];

  nixpkgs = {
    config.allowUnfree = true;
    overlays = [
      inputs.nur.overlays.default
    ];
  };

  age.secrets.gh-pat.file = ../secrets/gh-pat.age;

  nix = {
    extraOptions = ''
      !include ${config.age.secrets.gh-pat.path}
    '';

    optimise = {
      automatic = true;
      dates = [ "15:15" ];
    };
    settings = {
      extra-substituters = [ "https://vicinae.cachix.org" ];
      extra-trusted-public-keys = [ "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc=" ];

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
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };

  hardware = {
    enableRedistributableFirmware = true;
    bluetooth = {
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
  };

  boot = {
    loader.systemd-boot.enable = true;
    kernelParams = [
      "zswap.enabled=1"
      "zswap.compressor=zstd"
      "zswap.zpool=zsmalloc"
      "zswap.max_pool_percent=25"
    ];
  };

  systemd = {
    settings.Manager = {
      DefaultTimeoutStartSec = "90s";
    };
    user.services.xdg-desktop-portal-termfilechooser = {
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
  };

  system.autoUpgrade.enable = false;

  networking = {
    wireless.iwd = {
      enable = true;
      settings.General.EnableNetworkConfiguration = true;
    };
    networkmanager = {
      enable = true;
      wifi.backend = "iwd";
      dns = "none";
    };
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
      "9.9.9.9"
      "116.202.176.26"
    ];
  };

  services = {
    upower = {
      enable = true;
    };
    zerotierone = {
      enable = true;
      joinNetworks = [ "8d1c312afa2aad91" ];
    };
    pipewire = {
      enable = true;
      pulse.enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      jack.enable = true;
    };
    flatpak.enable = true;
    openssh.enable = true;
    #kmscon = {
    #  enable = true;
    #  hwRender = true;
    #  config = {
    #    font-name = "JetBrainsMono Nerd Font Mono";
    #  };
    #};
  };

  time.timeZone = "Europe/London";

  security = {
    rtkit.enable = true;
    pam.loginLimits = [
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
  };

  programs = {
    zsh.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    java.enable = true;
    appimage = {
      enable = true;
      binfmt = true;
    };
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        zlib
        openssl
        stdenv.cc.cc.lib
      ];
    };
    hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };
    kdeconnect.enable = true;
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

  documentation = {
    enable = true;
    man.enable = true;
  };
}
