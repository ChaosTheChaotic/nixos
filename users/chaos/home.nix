{
  config,
  pkgs,
  lib,
  inputs,
  cpuArch ? "generic",
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
    inherit cpuArch;
    mpdSrc = inputs.mpd;
  };
in
{
  imports = [
    ./shell.nix
    ./cli.nix
    ./gui.nix
    ./rmpc.nix
    ./equi/equi.nix
		./balatro/balatro.nix
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

    home.username = "chaos";
    home.homeDirectory = "/home/chaos";
    home.stateVersion = "25.11";

    programs.home-manager.enable = true;

    home.file.".config/hypr".source = config.lib.file.mkOutOfStoreSymlink "${config.dotfiles}/hypr";
    home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.dotfiles}/nvim";
    home.file.".config/bat".source = config.lib.file.mkOutOfStoreSymlink "${config.dotfiles}/bat";
    home.file.".config/quickshell".source =
      config.lib.file.mkOutOfStoreSymlink "${config.dotfiles}/quickshell";

    home.packages = with pkgs; [
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

      # Fonts
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      fantasque-sans-mono
      noto-fonts-color-emoji

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

      # Custom Inputs
      (inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (oldAttrs: {
        NIX_CFLAGS_COMPILE =
          (oldAttrs.NIX_CFLAGS_COMPILE or "")
          + (
            if cpuArch == "generic" then
              " -O3"
            else if pkgs.stdenv.hostPlatform.isAarch64 then
              " -mcpu=${cpuArch} -O3"
            else
              " -march=${cpuArch} -O3"
          );
      }))
      (inputs.tree-sitter.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (oldAttrs: {
        NIX_CFLAGS_COMPILE =
          (oldAttrs.NIX_CFLAGS_COMPILE or "")
          + (
            if cpuArch == "generic" then
              " -O3"
            else if pkgs.stdenv.hostPlatform.isAarch64 then
              " -mcpu=${cpuArch} -O3"
            else
              " -march=${cpuArch} -O3"
          );

        env =
          (oldAttrs.env or { })
          // (lib.optionalAttrs (cpuArch != "generic") {
            RUSTFLAGS = "-C target-cpu=${cpuArch} -C llvm-args=-vectorize-loops";
          });
      }))
      (inputs.clogite.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (oldAttrs: {
        env =
          (oldAttrs.env or { })
          // (lib.optionalAttrs (cpuArch != "generic") {
            RUSTFLAGS = "-C target-cpu=${cpuArch} -C llvm-args=-vectorize-loops";
          });

        zigBuildTarget = if cpuArch != "generic" then cpuArch else "baseline";

        zigBuildFlags = builtins.filter (flag: !(lib.hasPrefix "-Dcpu=" flag)) (
          oldAttrs.zigBuildFlags or [ ]
        );
      }))
      (inputs.tereix.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (oldAttrs: {
        NIX_CFLAGS_COMPILE =
          (oldAttrs.NIX_CFLAGS_COMPILE or "")
          + (
            if cpuArch == "generic" then
              " -O3"
            else if pkgs.stdenv.hostPlatform.isAarch64 then
              " -mcpu=${cpuArch} -O3"
            else
              " -march=${cpuArch} -O3"
          );
      }))
      rmpc-custom
    ];
    programs.quickshell = {
      enable = true;
    };

    systemd.user.settings = {
      Manager = {
        DefaultLimitNOFILE = "524288";
      };
    };
  };
}
