{
  config,
  pkgs,
  lib,
  inputs,
  arch,
  userName,
  ccache,
  osConfig,
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
  tereix = ccache.withCcache pkgs (
    arch.withCflags inputs.tereix.packages.${pkgs.stdenv.hostPlatform.system}.default
  );
  nixSearch = pkgs.writeShellScriptBin "ns" ''
    exec nix-search-tv print | ${pkgs.fzf}/bin/fzf \
      --preview 'nix-search-tv preview {}' \
      --scheme history \
      --bind 'ctrl-y:execute-silent(nix-search-tv source {} | wl-copy 2>/dev/null || true)'
  '';
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
      default = ../../config;
      example = ../../config;
      description = "Location of dotfiles";
    };
    apps = lib.mkOption {
      type = lib.types.path;
      default = ../../apps;
      example = ../../apps;
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
        ".config/quickshell".source = config.lib.file.mkOutOfStoreSymlink "${config.dotfiles}/quickshell";
      };
      packages = with pkgs; [
        # Development
        gcc
        zip
        unzip
        file
        which
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
        typescript
        zig
        kdePackages.qtdeclarative
        wf-recorder
        master.odin
        license-generator

        # Utilities
        scrcpy
        tesseract
        mpv
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
        nixSearch

        # Custom Inputs
        (ccache.withCcache pkgs (
          arch.withAll inputs.tree-sitter.packages.${pkgs.stdenv.hostPlatform.system}.default
        ))
        tereix
        (arch.withRustFlags inputs.ltyr.packages.${pkgs.stdenv.hostPlatform.system}.default)
        rmpc-custom

        (inputs.nvim.lib.mkNvim {
          inherit pkgs master tereix;
          balatroLsp = true;
        })

        (pkgs.callPackage ../../pkgs/blissify.nix { })
      ];
    };

    programs = {
      home-manager.enable = true;
      quickshell.enable = true;
      yacht = {
        enable = true;
        ttyWrap = true;
      };
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
      concord =
        let
          mpvBcon = pkgs.writeShellScriptBin "mpv" ''
            active_tty=$(cat /sys/class/tty/tty0/active 2>/dev/null)
            if [ -n "$active_tty" ] && [ -S "/run/bcon/handoff-$active_tty.sock" ] && [ -z "$WAYLAND_DISPLAY$DISPLAY" ]; then
              exec bcon handoff --input none --stop-keys q,esc -- \
                ${pkgs.mpv}/bin/mpv --vo=gpu --gpu-context=drm "$@"
            fi
            exec ${pkgs.mpv}/bin/mpv "$@"
          '';
        in
        {
          enable = true;
          package = pkgs.symlinkJoin {
            name = "concord-with-token";
            paths = [
              (pkgs.concord-tui.overrideAttrs (old: {
                patches = (old.patches or [ ]) ++ [ ../../patches/concord-spoof-windows.patch ];
                # The tests assert the host OS
                doCheck = false;
              }))
            ];
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/concord --run 'set -a; source ${osConfig.age.secrets.dc-tkn.path}; set +a' --prefix PATH : ${mpvBcon}/bin
            '';
          };
          settings = {
            display = {
              image_protocol = "kitty";
              show_avatars = true;
              show_images = true;
              show_custom_emoji = true;
              media_playback = true;
            };
            composer = {
              emojis_as_links = true;
            };
            updates.check_for_updates = false; # Manage through nix
            presence.share_rich_presence = false;
            voice = {
              self_mute = true;
              allow_microphone_transmit = true;
            };
          };
        };
      nix-search-tv = {
        enable = true;
        enableTelevisionIntegration = false;
        settings = {
          indexes = [
            "nixpkgs"
            "home-manager"
            "nixos"
          ];
        };
      };
    };

    xdg.configFile."concord/config.toml".force = lib.mkForce true; # Fix for nix complaining that the folder will be clobbered every time

    systemd.user.settings = {
      Manager = {
        DefaultLimitNOFILE = "524288";
      };
    };
  };
}
