{ config, pkgs, lib, inputs, ... }:

{
  options = {
    dotfiles = lib.mkOption {
      type = lib.types.path;
      apply = toString;
      default = "${builtins.toString ./.}/config";
      example = "${builtins.toString ./.}/config";
      description = "Location of dotfiles";
    };
  };

  config = {
    home.username = "chaos";
    home.homeDirectory = "/home/chaos";

    home.sessionPath = [
      "$HOME/.local/bin"
    ];
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
      cava
      btop
      playerctl
      hyprpaper
      sd
      fd
      shfmt
      stylua
      typescript
      wireplumber
      gjs
      gtksourceview5
      gtk4-layer-shell
      grim
      slurp
      libayatana-appindicator
      dart-sass
      sassc
      libsoup_3
      (ags.overrideAttrs (old: {
        buildInputs = old.buildInputs ++ [ pkgs.libdbusmenu-gtk3 ];
      }))
    ];
    home.stateVersion = "25.11";

    fonts.fontconfig.enable = true;

    programs.home-manager.enable = true;
    programs.atuin.enable = true;
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = "ChaosTheChaotic";
          email = "james.moriaty.ot@gmail.com";
        };
      };
    };
    programs.gh.enable = true;
    programs.zsh = {
      enable = true;
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
        export NIX_LD=$(nix eval --impure --raw --expr 'let pkgs = import <nixpkgs> {}; NIX_LD = pkgs.lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker"; in NIX_LD')
	fastfetch
      '';
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
        #font_family = "FantasqueSansM Nerd Font Mono";
        font_family = "JetBrains Mono Nerd Font";
        bold_font = "auto";
        italic_font = "auto";
        bold_italic_font = "auto";
        window_padding_width = 4;
        # The kitty theme starts here
        foreground = "#e0def4";
        background = "#232136";
        selection_foreground = "#e0def4";
        selection_background = "#44415a";
        cursor = "#56526e";
        cursor_text_color = "#e0def4";
        url_color = "#c4a7e7";
        active_tab_foreground = "#e0def4";
        active_tab_background = "#393552";
        inactive_tab_foreground = "#6e6a86";
        inactive_tab_background = "#232136";
        active_border_color = "#3e8fb0";
        inactive_border_color = "#44415a";
        # Black
        color0 = "#393552";
        color8 = "#6e6a86";
        # Red
        color1 = "#eb6f92";
        color9 = "#eb6f92";
        # Green
        color2 = "#3e8fb0";
        color19 = "#3e8fb0";
        # Yellow
        color3 = "#f6c117";
        color11 = "#f6c117";
        # Blue
        color4 = "#9ccfd8";
        color12 = "#9ccfd8";
        # Magenta
        color5 = "#c4a7e7";
        color13 = "#c4a7e7";
        # Cyan
        color6 = "#ea9a97";
        color14 = "#ea9a97";
        # White
        color7 = "#e0def4";
        color15 = "#e0def4";
      };
    };
    programs.waybar.enable = true;
    services.dunst.enable = true;
    xdg.configFile."waybar".source = config.lib.file.mkOutOfStoreSymlink "${config.dotfiles}/waybar";
    home.file.".config/hypr".source = config.lib.file.mkOutOfStoreSymlink "${config.dotfiles}/hypr";
    home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.dotfiles}/nvim";

    programs.floorp = {
      enable = true;
      profiles.default = {
	extensions = {
	  packages = with pkgs.nur.repos.rycee.firefox-addons; [
	    ublock-origin
	  ];
	};
      };
    };
    gtk = {
      enable = true;
      theme = {
	name = "rose-pine-moon";
	package = pkgs.rose-pine-gtk-theme;
      };
      iconTheme = {
	name = "rose-pine-moon";
	package = pkgs.rose-pine-icon-theme;
      };
    };
  };
}
