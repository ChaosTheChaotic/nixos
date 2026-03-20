{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ./shell.nix
    ./cli.nix
    ./gui.nix
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
    home.username = "chaos";
    home.homeDirectory = "/home/chaos";
    home.stateVersion = "25.11";

    programs.home-manager.enable = true;

    home.file.".config/hypr".source = config.lib.file.mkOutOfStoreSymlink "${config.dotfiles}/hypr";
    home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.dotfiles}/nvim";
    home.file.".config/bat".source = config.lib.file.mkOutOfStoreSymlink "${config.dotfiles}/bat";
    home.file.".config/quickshell".source = config.lib.file.mkOutOfStoreSymlink "${config.dotfiles}/quickshell";
    home.file.".config/lobster".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-cfg/config/lobster";

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

      # Fonts
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      fantasque-sans-mono
      noto-fonts-color-emoji

      # Utilities
      scrcpy
      tesseract
      imagemagick
      spotdl
      prismlauncher
      kdePackages.kdeconnect-kde
      libunwind
      qalculate-qt
      hyprpaper
      libnotify
      slurp
      wl-clipboard
      playerctl
      sd
      grim
      yt-dlp
      kdePackages.bluez-qt

      # Custom Inputs
      inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.clogite.packages.${pkgs.stdenv.hostPlatform.system}.default

      (equibop.overrideAttrs (oldAttrs: {
        ESBUILD_BINARY_PATH = "${pkgs.esbuild}/bin/esbuild";
        preBuild = (oldAttrs.preBuild or "") + ''
          echo "Patching esbuild version mismatch..."
          chmod -R u+w node_modules/esbuild
          find node_modules/esbuild -name "*.js" -exec sed -i 's/"0.27.2"/"${pkgs.esbuild.version}"/g' {} +
        '';
        postFixup = (oldAttrs.postFixup or "") + ''
          wrapProgram $out/bin/equibop --add-flags "--user-agent-os windows"
        '';
      }))
    ];
    programs.quickshell = {
      enable = true;
    };
  };
}
