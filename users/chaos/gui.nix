{
  config,
  pkgs,
  lib,
  ...
}:

{
  config = {
    gtk = {
      enable = true;
      gtk4.theme = config.gtk.theme;
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
        font_family = "JetBrains Mono Nerd Font";
	font_size = 8;
        bold_font = "auto";
        italic_font = "auto";
        bold_italic_font = "auto";
        window_padding_width = 4;
        # Theme
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
        # Colors
        color0 = "#393552";
        color8 = "#6e6a86";
        color1 = "#eb6f92";
        color9 = "#eb6f92";
        color2 = "#3e8fb0";
        color19 = "#3e8fb0";
        color3 = "#f6c117";
        color11 = "#f6c117";
        color4 = "#9ccfd8";
        color12 = "#9ccfd8";
        color5 = "#c4a7e7";
        color13 = "#c4a7e7";
        color6 = "#ea9a97";
        color14 = "#ea9a97";
        color7 = "#e0def4";
        color15 = "#e0def4";
      };
    };

    services.dunst = {
      enable = true;
      settings = {
        global = {
          monitor = 0;
          follow = "none";
          width = 300;
          height = 300;
          origin = "top-right";
          offset = "20x50";
          scale = 0;
          notification_limit = 20;
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
          alignment = "left";
          vertical_alignment = "center";
          line_height = 0;
          ellipsize = "middle";
          markup = "full";
          format = "<i>%s</i>\n%b";
          sort = "yes";
          show_indicators = "yes";
          font = "Monospace 14";
          icon_theme = "rose-pine-icons";
          enable_recursive_icon_lookup = true;
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
  };
}
