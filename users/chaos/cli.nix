{ ... }:

{
  config = {
    programs.bat.enable = true;

    programs.fd = {
      enable = true;
      extraOptions = [
        "--no-ignore"
        "--absolute-path"
      ];
      hidden = true;
      ignores = [ ".git/" ];
    };

    programs.aria2.enable = false;
    programs.jq.enable = true;

    programs.ripgrep-all.enable = false;
    programs.ripgrep.enable = true;

    programs.git = {
      enable = true;
      settings = {
        user = {
          name = "ChaosTheChaotic";
          email = "james.moriaty.ot@gmail.com";
        };
      };
			lfs.enable = true;
    };
    programs.gh.enable = true;
    programs.uv.enable = true;

    programs.lazygit = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        gui.theme = {
          activeBorderColor = [
            "#3e8fb0"
            "bold"
          ];
          inactiveBorderColor = [ "#6e6a86" ];
          searchingActiveBorderColor = [
            "#ea9a97"
            "bold"
          ];
          optionsTextColor = [ "#9ccfd8" ];
          selectedLineBgColor = [ "#3e8fb0" ];
          inactiveViewSelectedLineBgColor = [
            "#393552"
            "bold"
          ];
          cherryPickedCommitFgColor = [ "#2a273f" ];
          cherryPickedCommitBgColor = [ "#ea9a97" ];
          markedBaseCommitFgColor = [ "#9ccfd8" ];
          markedBaseCommitBgColor = [ "#f6c177" ];
          unstagedChangesColor = [ "#eb6f92" ];
          defaultFgColor = [ "#e0def4" ];
        };
      };
    };

    programs.eza = {
      enable = true;
      colors = "always";
      enableZshIntegration = true;
      icons = "auto";
      theme = {
        colourful = true;
        filekinds = {
          normal = {
            foreground = "#e0def4";
          };
          directory = {
            foreground = "#9ccfd8";
          };
          symlink = {
            foreground = "#56526e";
          };
          pipe = {
            foreground = "#908caa";
          };
          block_device = {
            foreground = "#ea9a97";
          };
          char_device = {
            foreground = "#f6c177";
          };
          socket = {
            foreground = "#2a283e";
          };
          special = {
            foreground = "#c4a7e7";
          };
          executable = {
            foreground = "#c4a7e7";
          };
          mount_point = {
            foreground = "#44415a";
          };
        };
        perms = {
          user_read = {
            foreground = "#908caa";
          };
          user_write = {
            foreground = "#44415a";
          };
          user_execute_file = {
            foreground = "#c4a7e7";
          };
          user_execute_other = {
            foreground = "#c4a7e7";
          };
          group_read = {
            foreground = "#908caa";
          };
          group_write = {
            foreground = "#44415a";
          };
          group_execute = {
            foreground = "#c4a7e7";
          };
          other_read = {
            foreground = "#908caa";
          };
          other_write = {
            foreground = "#44415a";
          };
          other_execute = {
            foreground = "#c4a7e7";
          };
          special_user_file = {
            foreground = "#c4a7e7";
          };
          special_other = {
            foreground = "#44415a";
          };
          attribute = {
            foreground = "#908caa";
          };
        };
        size = {
          major = {
            foreground = "#908caa";
          };
          minor = {
            foreground = "#9ccfd8";
          };
          number_byte = {
            foreground = "#908caa";
          };
          number_kilo = {
            foreground = "#56526e";
          };
          number_mega = {
            foreground = "#3e8fb0";
          };
          number_giga = {
            foreground = "#c4a7e7";
          };
          number_huge = {
            foreground = "#c4a7e7";
          };
          unit_byte = {
            foreground = "#908caa";
          };
          unit_kilo = {
            foreground = "#3e8fb0";
          };
          unit_mega = {
            foreground = "#c4a7e7";
          };
          unit_giga = {
            foreground = "#c4a7e7";
          };
          unit_huge = {
            foreground = "#9ccfd8";
          };
        };
        users = {
          user_you = {
            foreground = "#f6c177";
          };
          user_root = {
            foreground = "#eb6f92";
          };
          user_other = {
            foreground = "#c4a7e7";
          };
          group_yours = {
            foreground = "#56526e";
          };
          group_other = {
            foreground = "#6e6a86";
          };
          group_root = {
            foreground = "#eb6f92";
          };
        };
        links = {
          normal = {
            foreground = "#9ccfd8";
          };
          multi_link_file = {
            foreground = "#3e8fb0";
          };
        };
        git = {
          new = {
            foreground = "#9ccfd8";
          };
          modified = {
            foreground = "#f6c177";
          };
          deleted = {
            foreground = "#eb6f92";
          };
          renamed = {
            foreground = "#3e8fb0";
          };
          typechange = {
            foreground = "#c4a7e7";
          };
          ignored = {
            foreground = "#6e6a86";
          };
          conflicted = {
            foreground = "#ea9a97";
          };
        };
        git_repo = {
          branch_main = {
            foreground = "#908caa";
          };
          branch_other = {
            foreground = "#c4a7e7";
          };
          git_clean = {
            foreground = "#9ccfd8";
          };
          git_dirty = {
            foreground = "#eb6f92";
          };
        };
        security_context = {
          colon = {
            foreground = "#908caa";
          };
          user = {
            foreground = "#9ccfd8";
          };
          role = {
            foreground = "#c4a7e7";
          };
          typ = {
            foreground = "#6e6a86";
          };
          range = {
            foreground = "#c4a7e7";
          };
        };
        file_type = {
          image = {
            foreground = "#f6c177";
          };
          video = {
            foreground = "#eb6f92";
          };
          music = {
            foreground = "#9ccfd8";
          };
          lossless = {
            foreground = "#6e6a86";
          };
          crypto = {
            foreground = "#44415a";
          };
          document = {
            foreground = "#908caa";
          };
          compressed = {
            foreground = "#c4a7e7";
          };
          temp = {
            foreground = "#ea9a97";
          };
          compiled = {
            foreground = "#3e8fb0";
          };
          build = {
            foreground = "#6e6a86";
          };
          source = {
            foreground = "#ea9a97";
          };
        };
        punctuation = {
          foreground = "#56526e";
        };
        date = {
          foreground = "#3e8fb0";
        };
        inode = {
          foreground = "#908caa";
        };
        blocks = {
          foreground = "#9399B2";
        };
        header = {
          foreground = "#908caa";
        };
        octal = {
          foreground = "#9ccfd8";
        };
        flags = {
          foreground = "#c4a7e7";
        };
        symlink_path = {
          foreground = "#9ccfd8";
        };
        control_char = {
          foreground = "#3e8fb0";
        };
        broken_symlink = {
          foreground = "#eb6f92";
        };
        broken_path_overlay = {
          foreground = "#56526e";
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
          theme[main_bg]="#191724"
          theme[main_fg]="#e0def4"
          theme[title]="#908caa"
          theme[hi_fg]="#e0def4"
          theme[selected_bg]="#524f67"
          theme[selected_fg]="#f6c177"
          theme[inactive_fg]="#403d52"
          theme[graph_text]="#9ccfd8"
          theme[meter_bg]="#9ccfd8"
          theme[proc_misc]="#c4a7e7"
          theme[cpu_box]="#ebbcba"
          theme[mem_box]="#31748f"
          theme[net_box]="#c4a7e7"
          theme[proc_box]="#eb6f92"
          theme[div_line]="#6e6a86"
          theme[temp_start]="#ebbcba"
          theme[temp_mid]="#f6c177"
          theme[temp_end]="#eb6f92"
          theme[cpu_start]="#f6c177"
          theme[cpu_mid]="#ebbcba"
          theme[cpu_end]="#eb6f92"
          theme[free_start]="#eb6f92"
          theme[free_mid]="#eb6f92"
          theme[free_end]="#eb6f92"
          theme[cached_start]="#c4a7e7"
          theme[cached_mid]="#c4a7e7"
          theme[cached_end]="#c4a7e7"
          theme[available_start]="#31748f"
          theme[available_mid]="#31748f"
          theme[available_end]="#31748f"
          theme[used_start]="#ebbcba"
          theme[used_mid]="#ebbcba"
          theme[used_end]="#ebbcba"
          theme[download_start]="#31748f"
          theme[download_mid]="#9ccfd8"
          theme[download_end]="#9ccfd8"
          theme[upload_start]="#ebbcba"
          theme[upload_mid]="#eb6f92"
          theme[upload_end]="#eb6f92"
          theme[process_start]="#31748f"
          theme[process_mid]="#9ccfd8"
          theme[process_end]="#9ccfd8"
        '';
        rose-pine-moon = ''
          theme[main_bg]="#232136"
          theme[main_fg]="#e0def4"
          theme[title]="#908caa"
          theme[hi_fg]="#e0def4"
          theme[selected_bg]="#56526e"
          theme[selected_fg]="#f6c177"
          theme[inactive_fg]="#44415a"
          theme[graph_text]="#9ccfd8"
          theme[meter_bg]="#9ccfd8"
          theme[proc_misc]="#c4a7e7"
          theme[cpu_box]="#ea9a97"
          theme[mem_box]="#3e8fb0"
          theme[net_box]="#c4a7e7"
          theme[proc_box]="#eb6f92"
          theme[div_line]="#6e6a86"
          theme[temp_start]="#ea9a97"
          theme[temp_mid]="#f6c177"
          theme[temp_end]="#eb6f92"
          theme[cpu_start]="#f6c177"
          theme[cpu_mid]="#ea9a97"
          theme[cpu_end]="#eb6f92"
          theme[free_start]="#eb6f92"
          theme[free_mid]="#eb6f92"
          theme[free_end]="#eb6f92"
          theme[cached_start]="#c4a7e7"
          theme[cached_mid]="#c4a7e7"
          theme[cached_end]="#c4a7e7"
          theme[available_start]="#3e8fb0"
          theme[available_mid]="#3e8fb0"
          theme[available_end]="#3e8fb0"
          theme[used_start]="#ea9a97"
          theme[used_mid]="#ea9a97"
          theme[used_end]="#ea9a97"
          theme[download_start]="#3e8fb0"
          theme[download_mid]="#9ccfd8"
          theme[download_end]="#9ccfd8"
          theme[upload_start]="#ea9a97"
          theme[upload_mid]="#eb6f92"
          theme[upload_end]="#eb6f92"
          theme[process_start]="#3e8fb0"
          theme[process_mid]="#9ccfd8"
          theme[process_end]="#9ccfd8"
        '';
      };
    };
  };
}
