{ config, pkgs, lib, inputs, ... }:

let
  equibopVersion = "3.1.7";
  
  equibop = pkgs.appimageTools.wrapType2 {
    pname = "Equibop";
    version = equibopVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/Equicord/Equibop/releases/download/v${equibopVersion}/Equibop-${equibopVersion}-arm64.AppImage";
      sha256 = "sha256-v9Tl6WZ2qTjMzOgxKD6buNG4NrO7u9K4tUVy28/IgRg=";
    };
    #extraPkgs = pkgs: with pkgs; [ ];
    extraWrapperArgs = [ "--add-flags" "--user-agent-os windows" ];
  };
in {
  options = {
    dotfiles = lib.mkOption {
      type = lib.types.path;
      apply = toString;
      default = "${toString ./.}/config";
      example = "${toString ./.}/config";
      description = "Location of dotfiles";
    };
    apps = lib.mkOption {
      type = lib.types.path;
      apply = toString;
      default = "${toString ./.}/apps";
      example = "${toString ./.}/apps";
      description = "Location of applications";
    };
  };

  config = {
    home.username = "chaos";
    home.homeDirectory = "/home/chaos";

    home.sessionVariables = let
      NIX_HOME_BASE = "${config.home.homeDirectory}/nixos-cfg";
      SCRIPT_BASE_DIR = "${NIX_HOME_BASE}/scripts";
    in {
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
      ];
      LD_LIBRARY_PATH = with pkgs; lib.makeSearchPath "lib" [
	sqlite.out
	libunwind.out
      ];
      XDG_DATA_DIRS = "${config.apps}:$XDG_DATA_DIRS";
      UTIL_SCRIPT_DIR = "${SCRIPT_BASE_DIR}/util";
      BIN_SCRIPT_DIR = "${SCRIPT_BASE_DIR}/bin";
      WALLPAPER_DIR = "${NIX_HOME_BASE}/wallpapers";
      NIX_CFG_DIR = "${NIX_HOME_BASE}";
    };

    home.sessionPath = [
      "$HOME/.local/bin"
    ];
    home.packages = with pkgs; [
      gcc
      zip
      unzip
      file
      which
      neovim
      rsync
      bat
      pnpm
      nodejs
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
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
      playerctl
      hyprpaper
      sd
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
      libunwind
      cmake-language-server
      lua-language-server
      scrcpy
      equibop
      inputs.ashell.packages.${pkgs.system}.default
      inputs.vicinae.packages.${pkgs.system}.default
      tesseract
      imagemagick
    ];
    home.stateVersion = "25.11";

    fonts.fontconfig.enable = true;

    programs.home-manager.enable = true;
    programs.atuin.enable = true;
    programs.fd = {
      enable = true;
      extraOptions = ["--no-ignore" "--absolute-path"];
      hidden = true;
      ignores = [".git/"];
    };
    programs.fastfetch = {
      enable = true;
      settings = {

      };
    };
    programs.aria2 = {
      enable = false;
      # Currently uneeded
    };
    programs.jq = {
      enable = true;
    };
    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
    };
    programs.ripgrep-all = {
      enable = false;
      # No custom adapters need just yet
    };
    programs.ripgrep = {
      enable = true;
      #arguments = [ "-z" ];
    };
    programs.lazygit = {
      enable = true;
      enableZshIntegration = true;
      settings = {
	gui.theme = {
	  activeBorderColor = [ "#3e8fb0" "bold" ];
	  inactiveBorderColor = [ "#6e6a86" ];
	  searchingActiveBorderColor = [ "#ea9a97" "bold" ];
	  optionsTextColor = [ "#9ccfd8" ];
	  selectedLineBgColor = [ "#3e8fb0" ];
	  inactiveViewSelectedLineBgColor = [ "#393552" "bold" ];
	  cherryPickedCommitFgColor = [ "#2a273f" ];
	  cherryPickedCommitBgColor = [ "#ea9a97" ];
	  markedBaseCommitFgColor = [ "#9ccfd8" ];
	  markedBaseCommitBgColor = [ "#f6c177" ];
	  unstagedChangesColor = [ "#eb6f92" ];
	  defaultFgColor = [ "#e0def4" ];
	};
      };
    };
    programs.uv = {
      enable = true;
    };
    programs.eza = {
      enable = true;
      colors = "always";
      enableZshIntegration = true;
      icons = "auto";
      theme = ''
	colourful: true
	
	# Colors are in format of:
	# color/paletteRef (Description) #color code
	
	# Gold (Terminal Yellow) #f6c177
	# Love (Terminal Red) #eb6f92
	# Rose (Terminal Cyan) #ea9a97
	# Base (Primary Background) #232136
	# Iris (Terminal Magenta) #c4a7e7
	# Foam (Terminal Blue) #9ccfd8
	# Pine (Terminal Green)  #3e8fb0
	# Muted (Low Contrast Foreground) #6e6a86
	# Surface (Secondary Background Atop Base) #2a273f
	# Overlay (Tertiary Background Atop Surface) #393552
	# Subtle (Medium Contrast Foreground) #908caa
	# Text (High Contrast Foreground) #e0def4
	# Highlight Low (Low Contrast Highlight) #2a283e
	# Highlight Med (Medium Contrast Highlight) #44415a
	# Highlight High (High Contrast Highlight) #56526e
	
	filekinds:
	  normal: {foreground: "#e0def4"}
	  directory: {foreground: "#9ccfd8"}
	  symlink: {foreground: "#56526e"}
	  pipe: {foreground: "#908caa"}
	  block_device: {foreground: "#ea9a97"}
	  char_device: {foreground: "#f6c177"}
	  socket: {foreground: "#2a283e"}
	  special: {foreground: "#c4a7e7"}
	  executable: {foreground: "#c4a7e7"}
	  mount_point: {foreground: "#44415a"}
	
	perms:
	  user_read: {foreground: "#908caa"}
	  user_write: {foreground: "#44415a"}
	  user_execute_file: {foreground: "#c4a7e7"}
	  user_execute_other: {foreground: "#c4a7e7"}
	  group_read: {foreground: "#908caa"}
	  group_write: {foreground: "#44415a"}
	  group_execute: {foreground: "#c4a7e7"}
	  other_read: {foreground: "#908caa"}
	  other_write: {foreground: "#44415a"}
	  other_execute: {foreground: "#c4a7e7"}
	  special_user_file: {foreground: "#c4a7e7"}
	  special_other: {foreground: "#44415a"}
	  attribute: {foreground: "#908caa"}
	
	size:
	  major: {foreground: "#908caa"}
	  minor: {foreground: "#9ccfd8"}
	  number_byte: {foreground: "#908caa"}
	  number_kilo: {foreground: "#56526e"}
	  number_mega: {foreground: "#3e8fb0"}
	  number_giga: {foreground: "#c4a7e7"}
	  number_huge: {foreground: "#c4a7e7"}
	  unit_byte: {foreground: "#908caa"}
	  unit_kilo: {foreground: "#3e8fb0"}
	  unit_mega: {foreground: "#c4a7e7"}
	  unit_giga: {foreground: "#c4a7e7"}
	  unit_huge: {foreground: "#9ccfd8"}
	
	users:
	  user_you: {foreground: "#f6c177"}
	  user_root: {foreground: "#eb6f92"}
	  user_other: {foreground: "#c4a7e7"}
	  group_yours: {foreground: "#56526e"}
	  group_other: {foreground: "#6e6a86"}
	  group_root: {foreground: "#eb6f92"}
	
	links:
	  normal: {foreground: "#9ccfd8"}
	  multi_link_file: {foreground: "#3e8fb0"}
	
	git:
	  new: {foreground: "#9ccfd8"}
	  modified: {foreground: "#f6c177"}
	  deleted: {foreground: "#eb6f92"}
	  renamed: {foreground: "#3e8fb0"}
	  typechange: {foreground: "#c4a7e7"}
	  ignored: {foreground: "#6e6a86"}
	  conflicted: {foreground: "#ea9a97"}
	
	git_repo:
	  branch_main: {foreground: "#908caa"}
	  branch_other: {foreground: "#c4a7e7"}
	  git_clean: {foreground: "#9ccfd8"}
	  git_dirty: {foreground: "#eb6f92"}
	
	security_context:
	  colon: {foreground: "#908caa"}
	  user: {foreground: "#9ccfd8"}
	  role: {foreground: "#c4a7e7"}
	  typ: {foreground: "#6e6a86"}
	  range: {foreground: "#c4a7e7"}
	
	file_type:
	  image: {foreground: "#f6c177"}
	  video: {foreground: "#eb6f92"}
	  music: {foreground: "#9ccfd8"}
	  lossless: {foreground: "#6e6a86"}
	  crypto: {foreground: "#44415a"}
	  document: {foreground: "#908caa"}
	  compressed: {foreground: "#c4a7e7"}
	  temp: {foreground: "#ea9a97"}
	  compiled: {foreground: "#3e8fb0"}
	  build: {foreground: "#6e6a86"}
	  source: {foreground: "#ea9a97"}
	
	punctuation: {foreground: "#56526e"}
	date: {foreground: "#3e8fb0"}
	inode: {foreground: "#908caa"}
	blocks: {foreground: "#9399B2"}
	header: {foreground: "#908caa"}
	octal: {foreground: "#9ccfd8"}
	flags: {foreground: "#c4a7e7"}
	
	symlink_path: {foreground: "#9ccfd8"}
	control_char: {foreground: "#3e8fb0"}
	broken_symlink: {foreground: "#eb6f92"}
	broken_path_overlay: {foreground: "#56526e"}
      '';
    };
    programs.cava = {
      enable = true;
      settings = {
	color = {
	  background = "'#232136'";
	  gradient = "1";
	  gradient_count = 6;
	  gradient_color_1 = "'#3e8fb0'";
	  gradient_color_2 = "'#9ccfd8'";
	  gradient_color_3 = "'#c4a7e7'";
	  gradient_color_4 = "'#ea9a97'";
	  gradient_color_5 = "'#f6c177'";
	  gradient_color_6 = "'#eb6f92'";
	  #background = "'#191724'";
	  #gradient = 1;
	  #gradient_count = 6;
	  #gradient_color_1 = "'#31748f'";
	  #gradient_color_2 = "'#9ccfd8'";
	  #gradient_color_3 = "'#c4a7e7'";
	  #gradient_color_4 = "'#ebbcba'";
	  #gradient_color_5 = "'#f6c177'";
	  #gradient_color_6 = "'#eb6f92'";
	};
      };
    };
    programs.btop = {
      enable = true;
      settings = {
	color_theme = "rose-pine";
	theme_background = false;
	truecolor = true;
	rounded_corners = true;
	terminal_sync = true;
      };
      themes = {
	rose-pine = ''
# Main background, empty for terminal default, need to be empty if you want transparent background
theme[main_bg]="#191724"
# Base

# Main text color
theme[main_fg]="#e0def4"
# Text

# Title color for boxes
theme[title]="#908caa"
# Subtle

# Highlight color for keyboard shortcuts
theme[hi_fg]="#e0def4"
# Text

# Background color of selected item in processes box
theme[selected_bg]="#524f67"
# HL High

# Foreground color of selected item in processes box
theme[selected_fg]="#f6c177"
# Gold

# Color of inactive/disabled text
theme[inactive_fg]="#403d52"
# HL Med

# Color of text appearing on top of graphs, i.e uptime and current network graph scaling
theme[graph_text]="#9ccfd8"
# Foam

# Background color of the percentage meters
theme[meter_bg]="#9ccfd8"
# Foam

# Misc colors for processes box including mini cpu graphs, details memory graph and details status text
theme[proc_misc]="#c4a7e7"
# Iris

# Cpu box outline color
theme[cpu_box]="#ebbcba"
# Rose

# Memory/disks box outline color
theme[mem_box]="#31748f"
# Pine

# Net up/down box outline color
theme[net_box]="#c4a7e7"
# Iris

# Processes box outline color
theme[proc_box]="#eb6f92"
# Love

# Box divider line and small boxes line color
theme[div_line]="#6e6a86"
# Muted

# Temperature graph colors
theme[temp_start]="#ebbcba"
# Rose
theme[temp_mid]="#f6c177"
# Gold
theme[temp_end]="#eb6f92"
# Love

# CPU graph colors
theme[cpu_start]="#f6c177"
# Gold
theme[cpu_mid]="#ebbcba"
# Rose
theme[cpu_end]="#eb6f92"
# Love

# Mem/Disk free meter
# all love
theme[free_start]="#eb6f92"
theme[free_mid]="#eb6f92"
theme[free_end]="#eb6f92"

# Mem/Disk cached meter
# all iris
theme[cached_start]="#c4a7e7"
theme[cached_mid]="#c4a7e7"
theme[cached_end]="#c4a7e7"

# Mem/Disk available meter
# all pine
theme[available_start]="#31748f"
theme[available_mid]="#31748f"
theme[available_end]="#31748f"

# Mem/Disk used meter
# all rose
theme[used_start]="#ebbcba"
theme[used_mid]="#ebbcba"
theme[used_end]="#ebbcba"

# Download graph colors
# Pine for start, foam for the rest
theme[download_start]="#31748f"
theme[download_mid]="#9ccfd8"
theme[download_end]="#9ccfd8"

# Upload graph colors
theme[upload_start]="#ebbcba"
# Rose for start
theme[upload_mid]="#eb6f92"
# Love for mid and end
theme[upload_end]="#eb6f92"

# Process box color gradient for threads, mem and cpu usage
theme[process_start]="#31748f"
# Pine
theme[process_mid]="#9ccfd8"
# Foam for mid and end
theme[process_end]="#9ccfd8"
	'';
	rose-pine-moon = ''
# Main background, empty for terminal default, need to be empty if you want transparent background
theme[main_bg]="#232136"

# Main text color
theme[main_fg]="#e0def4"

# Title color for boxes
theme[title]="#908caa"

# Highlight color for keyboard shortcuts
theme[hi_fg]="#e0def4"

# Background color of selected item in processes box
theme[selected_bg]="#56526e"

# Foreground color of selected item in processes box
theme[selected_fg]="#f6c177"

# Color of inactive/disabled text
theme[inactive_fg]="#44415a"

# Color of text appearing on top of graphs, i.e uptime and current network graph scaling
theme[graph_text]="#9ccfd8"

# Background color of the percentage meters
theme[meter_bg]="#9ccfd8"

# Misc colors for processes box including mini cpu graphs, details memory graph and details status text
theme[proc_misc]="#c4a7e7"

# Cpu box outline color
theme[cpu_box]="#ea9a97"

# Memory/disks box outline color
theme[mem_box]="#3e8fb0"

# Net up/down box outline color
theme[net_box]="#c4a7e7"

# Processes box outline color
theme[proc_box]="#eb6f92"

# Box divider line and small boxes line color
theme[div_line]="#6e6a86"

# Temperature graph colors
theme[temp_start]="#ea9a97"
theme[temp_mid]="#f6c177"
theme[temp_end]="#eb6f92"

# CPU graph colors
theme[cpu_start]="#f6c177"
theme[cpu_mid]="#ea9a97"
theme[cpu_end]="#eb6f92"

# Mem/Disk free meter
theme[free_start]="#eb6f92"
theme[free_mid]="#eb6f92"
theme[free_end]="#eb6f92"

# Mem/Disk cached meter
theme[cached_start]="#c4a7e7"
theme[cached_mid]="#c4a7e7"
theme[cached_end]="#c4a7e7"

# Mem/Disk available meter
theme[available_start]="#3e8fb0"
theme[available_mid]="#3e8fb0"
theme[available_end]="#3e8fb0"

# Mem/Disk used meter
theme[used_start]="#ea9a97"
theme[used_mid]="#ea9a97"
theme[used_end]="#ea9a97"

# Download graph colors
theme[download_start]="#3e8fb0"
theme[download_mid]="#9ccfd8"
theme[download_end]="#9ccfd8"

# Upload graph colors
theme[upload_start]="#ea9a97"
theme[upload_mid]="#eb6f92"
theme[upload_end]="#eb6f92"

# Process box color gradient for threads, mem and cpu usage
theme[process_start]="#3e8fb0"
theme[process_mid]="#9ccfd8"
theme[process_end]="#9ccfd8"
	'';
      };
    };
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
	scrcpy = "scrcpy --render-driver=opengl";
      };
      sessionVariables = {
        EDITOR = "nvim";
	BAT_THEME="rose-pine-moon";
      };
      #syntaxHighlighting.enable = true;
      autosuggestion.enable = true;
      oh-my-zsh = {
        enable = true;
	#theme = "xiong-chiamiov-plus";
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
      plugins = [
        {
          name = "F-Sy-H";
          src = inputs.f-sy-h;
        }
        {
          name = "vi-mode";
          src = pkgs.zsh-vi-mode;
          file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
        }
      ];
      initContent = ''
        export NIX_LD=$(nix eval --impure --raw --expr 'let pkgs = import <nixpkgs> {}; NIX_LD = pkgs.lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker"; in NIX_LD')
	man() {
	  MANPAGER="sh -c 'sed -u -e \"s/\\x1B\[[0-9;]*m//g; s/.\\x08//g\" | bat -p -lman'" command man "$@"
	}
	fastfetch
      '';
    };

    programs.starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        add_newline = false;
        format = "$username$hostname$directory$git_branch$git_commit$git_status$nix_shell$status$character";

	nix_shell = {
	  symbol = "󱄅 ";
	  style = "bold iris"; 
	  format = "via [$symbol$state]($style) ";
	};
    
	status = {
	  disabled = false;
	  symbol = "󰅖 "; 
	  success_symbol = "󰄬 ";
	  
	  style = "bold love";
	  success_style = "bold pine";
	  
	  format = "[$symbol$signal_name$maybe_int]($style) ";
	  
	  not_executable_symbol = "󱆃 ";
	  not_found_symbol = "󰍉 ";
	  sigint_symbol = "󰈑 ";
	  map_symbol = true;
	};
    
        palette = "rose-pine";
        palettes.rose-pine = {
          rose = "#ebbcba";
          iris = "#c4a7e7";
          gold = "#f6c177";
          love = "#eb6f92";
          pine = "#31748f";
          foam = "#9ccfd8";
        };
      };
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
    home.file.".config/ashell".source = config.lib.file.mkOutOfStoreSymlink "${config.dotfiles}/ashell";
    home.file.".config/lobster".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-cfg/config/lobster";

    programs.floorp = {
      enable = true;
      profiles.default = {
	extensions = {
	  packages = with pkgs.nur.repos.rycee.firefox-addons; [
	    ublock-origin
	    return-youtube-dislikes
	    sponsorblock
	    vimium-c
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
