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
        search = {
          force = true;
          default = "SearXNG";
          engines = {
            "SearXNG" = {
              urls = [
                {
                  template = "https://priv.au/search";
                  params = [
                    {
                      name = "q";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              icon = "https://priv.au/favicon.ico";
              definedAliases = [ "@sx" ];
            };
          };
        };
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
  };
}
