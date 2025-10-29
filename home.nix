{ config, pkgs, ... }:

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

  home.stateVersion = "25.11";
}
