{
  config,
  pkgs,
  inputs,
  ...
}:

{
  config = {
    home.sessionVariables = {
      GSK_RENDERER = "ngl";
      GDK_BACKEND = "wayland";
      LAYER_SHELL_ENABLE = "1";
      GI_TYPELIB_PATH =
        with pkgs;
        lib.makeSearchPath "lib/girepository-1.0" [
          networkmanager
          gtk4
          graphene
          gtksourceview5
          gtk4-layer-shell
          libsoup_3
        ];
      LD_LIBRARY_PATH =
        with pkgs;
        lib.makeSearchPath "lib" [
          sqlite.out
          libunwind.out
        ];
      XDG_DATA_DIRS = "${config.apps}:$XDG_DATA_DIRS";
      QML_IMPORT_PATH =
        with pkgs;
        lib.makeSearchPath "lib/qt-6/qml" [
          quickshell
          kdePackages.qtdeclarative
          kdePackages.bluez-qt
        ];
    } // import ../../modules/consts.nix { homeDir = config.home.homeDirectory; };

    home.sessionPath = [
      "$HOME/.local/bin"
    ];

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
        rb = "sudo systemd-inhibit --what=handle-lid-switch --why=\"NixOS rebuild\" nixos-rebuild switch --flake /etc/nixos";
        scrcpy = "scrcpy --render-driver=opengl";
      };
      sessionVariables = {
        EDITOR = "nvim";
        BAT_THEME = "rose-pine-moon";
      };
      autosuggestion.enable = true;
      oh-my-zsh = {
        enable = true;
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
        man() {
          MANPAGER="sh -c 'sed -u -e \"s/\\x1B\[[0-9;]*m//g;s/.\\x08//g\" | bat -p -lman'" command man "$@"
        }
	zvm_after_init_commands+=('eval "$(clogite init)"')
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
        palette = "rose-pine-moon";
        palettes.rose-pine-moon = {
          overlay = "#393552";
          love = "#eb6f92";
          gold = "#f6c177";
          rose = "#ea9a97";
          pine = "#3e8fb0";
          foam = "#9ccfd8";
          iris = "#c4a7e7";
        };
      };
    };

    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
