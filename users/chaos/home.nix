{
  config,
  pkgs,
  lib,
  inputs,
  arch,
  userName,
  ccache,
  ...
}:

let
  master = import inputs.nixpkgs-master {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
    overlays = [
      (final: prev: {
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (python-final: python-prev: {
            curl-cffi = python-prev.curl-cffi.overridePythonAttrs (oldAttrs: {
              doCheck = false;
            });
          })
        ];
      })
    ];
  };
  rmpc-custom = pkgs.callPackage ../../pkgs/rmpc.nix {
    inherit arch;
    mpdSrc = inputs.mpd;
    stdenv = ccache.stdenv pkgs;
  };
in
{
  imports = [
    ./shell.nix
    ./cli.nix
    ./gui.nix
    ./rmpc.nix
    ./music-rename.nix
    ./sysstat.nix
    ./equi/equi.nix
    ./balatro/balatro.nix
    ./stylix.nix
    ../../modules/palette.nix
  ];

  options = {
    dotfiles = lib.mkOption {
      type = lib.types.path;
      apply = toString;
      default = "${toString ../../config}";
      example = "${toString ../../config}";
      description = "Location of dotfiles";
    };
    apps = lib.mkOption {
      type = lib.types.path;
      apply = toString;
      default = "${toString ../../apps}";
      example = "${toString ../../apps}";
      description = "Location of applications";
    };
  };

  config = {

    _module.args.master = master;

    home = {
      username = "${userName}";
      homeDirectory = "/home/${userName}";
      stateVersion = "25.11";
      file = {
        ".config/hypr".source = config.lib.file.mkOutOfStoreSymlink "${config.dotfiles}/hypr";
        ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.dotfiles}/nvim";
        ".config/quickshell".source = config.lib.file.mkOutOfStoreSymlink "${config.dotfiles}/quickshell";
      };
      packages = with pkgs; [
        # Development
        gcc
        zip
        unzip
        file
        which
        neovim
        rsync
        pnpm
        nodejs
        gnumake
        lua
        luarocks
        clang-tools
        rustup
        pkg-config
        openssl
        nixfmt
        nixd
        shfmt
        stylua
        typescript
        cmake-language-server
        lua-language-server
        zig
        hyprls
        kdePackages.qtdeclarative
        ruff
        prettier
        google-java-format
        wf-recorder
        master.odin
        master.ols

        # Utilities
        scrcpy
        tesseract
        imagemagick
        master.spotdl
        prismlauncher
        kdePackages.kdeconnect-kde
        libunwind
        qalculate-qt
        wbg
        libnotify
        slurp
        wl-clipboard
        playerctl
        sd
        grim
        master.yt-dlp
        kdePackages.bluez-qt
        (master.ani-cli.overrideAttrs (oldAttrs: {
          runtimeInputs = (oldAttrs.runtimeInputs or [ ]) ++ [
            botan3
          ];
          src = inputs.ani-cli;
        }))
        git-filter-repo
        nix-prefetch-github
        shellcheck
        nix-output-monitor

        # Custom Inputs
        (ccache.withCcache pkgs (
          arch.withAll inputs.tree-sitter.packages.${pkgs.stdenv.hostPlatform.system}.default
        ))
        (ccache.withCcache pkgs (
          arch.withCflags inputs.tereix.packages.${pkgs.stdenv.hostPlatform.system}.default
        ))
        rmpc-custom
      ];
    };

    programs.home-manager.enable = true;

    programs = {
      quickshell.enable = true;
      clogite = {
        enable = true;
        keepHistfile = false;
        modifyZshAutosuggestions = true;
        package =
          inputs.clogite.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
            (oldAttrs: {
              env = (oldAttrs.env or { }) // {
                RUSTFLAGS = arch.rustFlags;
              };

              zigBuildTarget = arch.zigTarget;

              zigBuildFlags = builtins.filter (flag: !(lib.hasPrefix "-Dcpu=" flag)) (
                oldAttrs.zigBuildFlags or [ ]
              );
            });
      };
      vicinae = {
        package = ccache.withCmakeLauncher pkgs (
          inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
            nodejs = pkgs.nodejs;
          }
        );
        enable = true;
        systemd = {
          enable = true;
          environment = {
            USE_LAYER_SHELL = 1;
            QSG_RHI_BACKEND = "vulkan";
          };
        };
        settings = {
          search_files_in_root = true;
          theme = {
            dark = {
              name = "rose-pine-moon";
              icon = "oomox-rose-pine-moon";
            };
          };
          launcher_window = {
            opacity = 0.7;
          };
          telemetry = {
            system_info = false;
          };
          favourites = [
            "clipboard:history"
            "applications:floorp"
            "applications:equibop"
          ];
        };
        extensions = with inputs.vicinae-extensions.packages.${pkgs.stdenv.hostPlatform.system}; [
          # TODO: Monitor the commented out extensions for when they are fixed
          #bluetooth
          #dbus
          nix
          process-manager
          player-pilot
          #systemd
          fuzzy-files
          wifi-commander
          nerdfont-search
        ];
      };
    };

    systemd.user.settings = {
      Manager = {
        DefaultLimitNOFILE = "524288";
      };
    };
  };
}
