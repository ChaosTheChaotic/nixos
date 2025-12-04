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
    apps = lib.mkOption {
      type = lib.types.path;
      apply = toString;
      default = "${builtins.toString ./.}/apps";
      example = "${builtins.toString ./.}/apps";
      description = "Location of applications";
    };
  };

  config = {
    home.username = "chaos";
    home.homeDirectory = "/home/chaos";

    home.sessionVariables = {
      GSK_RENDERER = "ngl";
      GDK_BACKEND = "wayland";
      LAYER_SHELL_ENABLE = "1";
      GI_TYPELIB_PATH = with pkgs; lib.makeSearchPath "lib/girepository-1.0" [
	networkmanager
        gtk4
        graphene
        gtksourceview5
        gtk4-layer-shell
        libsoup_3
	astal.hyprland
      	astal.wireplumber
      	astal.network
      	astal.apps
      	astal.bluetooth
      	astal.powerprofiles
      	astal.notifd
      	astal.mpris
      	astal.battery
      	astal.tray
      ];
      GSETTINGS_SCHEMA_DIR = "${pkgs.astal.notifd}/share/gsettings-schemas/astal-notifd-0-unstable-2025-11-07/glib-2.0/schemas";
      GIO_MODULE_DIR = "${pkgs.glib-networking}/lib/gio/modules/";
      LD_LIBRARY_PATH = with pkgs; lib.makeSearchPath "lib" [
	sqlite.out
      ];
      XDG_DATA_DIRS = "${config.apps}:$XDG_DATA_DIRS";
    };

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
      wl-clipboard
      qalculate-qt
      base16-schemes
      libnotify
      libayatana-appindicator
      gobject-introspection
      noto-fonts-color-emoji
      spotdl
      prismlauncher
      kdePackages.kdeconnect-kde
      astal.hyprland
      astal.wireplumber
      astal.network
      astal.apps
      astal.bluetooth
      astal.powerprofiles
      astal.notifd
      astal.mpris
      astal.battery
      astal.tray
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
	img = "kitty icat";
        lg = "lazygit";
	prismlauncher = "prismlauncher -d ${config.dotfiles}/PrismLauncher";
        rb = "sudo nixos-rebuild switch --flake /etc/nixos";
      };
      sessionVariables = {
        EDITOR = "nvim";
	BAT_THEME="rose-pine-moon";
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
	man() {
	  MANPAGER="sh -c 'sed -u -e \"s/\\x1B\[[0-9;]*m//g; s/.\\x08//g\" | bat -p -lman'" command man "$@"
	}
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
    services.dunst = {
      enable = true;
      settings = {
        global = {
          # Geometry and positioning
          monitor = 0;
          follow = "none";
          width = 300;
          height = 300;
          origin = "top-right";
          offset = "20x50";
          scale = 0;
          notification_limit = 20;
          
          # Appearance
          transparency = 0;
          corner_radius = 20;
          icon_corner_radius = 10;
          frame_width = 2;
          gap_size = 15;
          padding = 15;
          horizontal_padding = 15;
          text_icon_padding = 40;
          separator_height = 2;
          separator_color = "frame";
          
          # Text and formatting
          alignment = "left";
          vertical_alignment = "center";
          line_height = 0;
          ellipsize = "middle";
          markup = "full";
          format = "<i>%s</i>\n%b";
          sort = "yes";
          show_indicators = "yes";
          font = "Monospace 14";
          
          # Icons
          icon_theme = "rose-pine-icons";
          enable_recursive_icon_lookup = true;
          
          # Colors
          highlight = "#FF470A";
          frame_color = "#191724";
          background = "#191724";
          foreground = "#e0def4";
        };
        
        experimental = {
          per_monitor_dpi = false;
        };
    
        urgency_low = {
          background = "#393955";
          foreground = "#908caa";
          frame_color = "#3e8fb0";
          highlight = "#3e8fb0";
          timeout = 10;
          default_icon = "dialog-information";
          format = "<i>%s</i>\n<b><span foreground='#3e8fb0'>%b</span></b>";
        };
    
        urgency_normal = {
          background = "#151515bb";
          foreground = "#ffffff";
          frame_color = "#151515c8";
          highlight = "#f6c177";
          timeout = 10;
          default_icon = "dialog-warning";
          format = "<i>%s</i>\n<b><span foreground='#f6c177'>%b</span></b>";
        };
    
        urgency_critical = {
          background = "#900000";
          foreground = "#ffffff";
          frame_color = "#ff0000";
          highlight = "#eb6f92";
          timeout = 0;
          default_icon = "dialog-error";
          format = "<i>%s</i>\n<b><span foreground='#eb6f92'>%b</span></b>";
        };
      };
    };

    home.file.".config/hypr".source = config.lib.file.mkOutOfStoreSymlink "${config.dotfiles}/hypr";
    home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.dotfiles}/nvim";
    home.file.".config/bat".source = config.lib.file.mkOutOfStoreSymlink "${config.dotfiles}/bat";
    home.file.".config/ags".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-cfg/config/ags";
    home.file.".config/lobster".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-cfg/config/lobster";

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
    services.cliphist = {
      enable = true;
      allowImages = true;
    };
    programs.hyprlock.enable = true;
  };
}
