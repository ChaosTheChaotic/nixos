{ lib, vp, ... }:

let
  toLua = lib.nixvim.toLuaObject;

  button = shortcut: label: cmd: {
    type = "button";
    val = label;
    on_press.__raw = ''
      function()
        local key = vim.api.nvim_replace_termcodes(${toLua cmd} .. "<Ignore>", true, false, true)
        vim.api.nvim_feedkeys(key, "t", false)
      end
    '';
    opts = {
      position = "center";
      shortcut = "[${shortcut}] ";
      cursor = 3;
      width = 50;
      align_shortcut = "right";
      hl_shortcut = "Keyword";
      keymap = [
        "n"
        shortcut
        cmd
        {
          noremap = true;
          silent = true;
          nowait = true;
        }
      ];
    };
  };

  alphaConfig = {
    layout = [
      {
        type = "padding";
        val.__raw = "vim.fn.max { 2, vim.fn.floor(vim.fn.winheight(0) * 0.2) }";
      }
      {
        type = "text";
        val = [
          "                                                                     "
          "       ████ ██████           █████      ██                     "
          "      ███████████             █████                             "
          "      █████████ ███████████████████ ███   ███████████   "
          "     █████████  ███    █████████████ █████ ██████████████   "
          "    █████████ ██████████ █████████ █████ █████ ████ █████   "
          "  ███████████ ███    ███ █████████ █████ █████ ████ █████  "
          " ██████  █████████████████████ ████ █████ █████ ████ ██████ "
        ];
        opts = {
          position = "center";
          hl = "Type";
        };
      }
      {
        type = "padding";
        val = 2;
      }
      {
        type = "group";
        val = [
          (button "e" "  New file" ":ene <BAR> startinsert <CR>")
          (button "f" "󰈞  Find file" ":Telescope find_files<CR>")
          (button "g" "  LazyGit" ":LazyGit<CR>")
          (button "c" "  Configuration" ":e $NIX_CFG_DIR/users/chaos/nvim/default.nix<CR>")
          (button "q" "󰈆  Quit Neovim" ":qa<CR>")
        ];
        opts.spacing = 1;
      }
      {
        type = "text";
        val = "";
        opts = {
          position = "center";
          hl = "Number";
        };
      }
    ];
    opts.margin = 5;
  };
in
{
  extraPlugins = [
    vp.alpha-nvim
    vp.lsp-lines-nvim
  ];

  extraConfigLua = ''
    require("alpha").setup(${toLua alphaConfig})
    require("lsp_lines").setup()
  '';

  plugins.web-devicons = {
    enable = true;
    package = vp.nvim-web-devicons;
  };

  plugins.fidget = {
    enable = true;
    package = vp.fidget-nvim;
  };

  plugins.colorizer = {
    enable = true;
    package = vp.nvim-colorizer-lua;
  };

  plugins.gitsigns = {
    enable = true;
    package = vp.gitsigns-nvim;
    settings = {
      signs = {
        add.text = "+";
        change.text = "~";
        delete.text = "_";
        topdelete.text = "‾";
        changedelete.text = "~";
      };
      current_line_blame = true;
    };
  };

  plugins.lualine = {
    enable = true;
    package = vp.lualine-nvim;
    settings = {
      options = {
        theme = "auto";
        component_separators = {
          left = "";
          right = "";
        };
        section_separators = {
          left = "";
          right = "";
        };
        icons_enabled = true;
      };
      sections = {
        lualine_a = [ "mode" ];
        lualine_b = [
          {
            __unkeyed-1 = "branch";
            icon = "";
          }
          {
            __unkeyed-1 = "diff";
            symbols = {
              added = " ";
              modified = " ";
              removed = " ";
            };
            colored = false;
          }
          {
            __unkeyed-1 = "diagnostics";
            symbols = {
              error = " ";
              warn = " ";
              info = " ";
              hint = " ";
            };
          }
        ];
        lualine_c = [ "filename" ];
        lualine_x = [
          {
            __unkeyed-1 = "encoding";
            fmt.__raw = "string.upper";
          }
          {
            __unkeyed-1 = "fileformat";
            symbols = {
              unix = "";
              dos = "";
              mac = "";
            };
          }
          {
            __unkeyed-1 = "filetype";
            icon.align = "right";
          }
        ];
        lualine_y = [ "progress" ];
        lualine_z = [ "location" ];
      };
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>gb";
      action = "<cmd>Gitsigns toggle_current_line_blame<CR>";
      options.desc = "Toggle line blame";
    }
    {
      mode = [
        "n"
        "x"
        "o"
      ];
      key = "<Leader>l";
      action.__raw = "function() vim.diagnostic.config({ virtual_lines = not vim.diagnostic.config().virtual_lines }) end";
      options.desc = "Toggle LSP lines";
    }
  ];
}
