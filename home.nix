{ config, pkgs, lib, ... }:

{
  home.username = "chaos";
  home.homeDirectory = "/home/chaos";

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  fonts.fontconfig.enable = true;

  programs.home-manager.enable = true;
  programs.atuin.enable = true;
  home.packages = with pkgs; [
    fastfetch
    gcc
    ripgrep
    jq
    zip
    unzip
    file
    which
    neovim
    zoxide
    uv
    rsync
    bat
    pnpm
    lazygit
    nodejs
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    eza
    gnumake
    lua
    luarocks
    clang-tools
    rustup
    pkg-config
    openssl
    nixfmt
    nixd
    fantasque-sans-mono
  ];

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "ChaosTheChaotic";
        email = "james.moriaty.ot@gmail.com";
      };
    };
  };

  programs.gh = {
    enable = true;
  };

  programs.zsh = {
    enable = true;
    shellAliases = { };
    shellAliases = {
      lla = "eza -al";
      lt = "eza -alT";
      cp = "cp -rv";
      mv = "mv -v";
      lg = "lazygit";
      rb = "sudo nixos-rebuild switch --flake /etc/nixos";
    };
    sessionVariables = {
      EDITOR = "nvim";
    };
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "xiong-chiamiov-plus";
      plugins = [
        "git"
        "sudo"
        "systemadmin"
        "git-prompt"
        "rsync"
        "web-search"
        "alias-finder"
        "zoxide"
      ];
    };
    initContent = ''
      export NIX_LD=$(nix eval --impure --raw --expr 'let pkgs = import <nixpkgs> {}; NIX_LD = pkgs.lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker"; in NIX_LD')'';
  };

  wayland.windowManager.hyprland.settings = {
    "$mod" = "SUPER";
  };

  programs.kitty = lib.mkForce {
    enable = true;
    enableGitIntegration = true;
    settings = {
      confirm_os_window_close = 0;
      dynamic_background_opacity = true;
      enable_audio_bell = false;
      background_opacity = "0.3";
      background_blur = 5;
      cursor_trail = 1;
      font_family = "FantasqueSansM Nerd Font Mono";
      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";
      window_padding_width = 4;
    };
  };

  home.stateVersion = "25.11";
}
