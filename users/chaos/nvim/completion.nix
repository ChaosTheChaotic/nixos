{
  inputs,
  pkgs,
  vp,
  ...
}:

{
  extraPlugins = [
    vp.friendly-snippets
    vp.colorful-menu-nvim
  ];

  plugins.blink-cmp = {
    enable = true;
    package = inputs.blink-cmp.packages.${pkgs.stdenv.hostPlatform.system}.default;
    settings = {
      keymap = {
        preset = "default";
        "<Up>" = [
          "select_prev"
          "fallback"
        ];
        "<Down>" = [
          "select_next"
          "fallback"
        ];
        # snippet_forward added so <Tab> also jumps between snippet fields
        "<Tab>" = [
          "select_and_accept"
          "snippet_forward"
          "fallback"
        ];
      };
      appearance = {
        use_nvim_cmp_as_default = true;
        nerd_font_variant = "mono";
      };
      # Built in snippet engine (vim.snippet) + friendly-snippets, replaces LuaSnip
      snippets.preset = "default";
      sources.default = [
        "lsp"
        "path"
        "snippets"
        "buffer"
      ];
      signature.enabled = true;
      completion = {
        documentation = {
          auto_show = true;
          auto_show_delay_ms = 10;
        };
        menu.draw = {
          # label + label_description are merged into label by colorful-menu.
          columns = [
            [ "kind_icon" ]
            {
              __unkeyed-1 = "label";
              gap = 1;
            }
          ];
          components.label = {
            text.__raw = "function(ctx) return require('colorful-menu').blink_components_text(ctx) end";
            highlight.__raw = "function(ctx) return require('colorful-menu').blink_components_highlight(ctx) end";
          };
        };
      };
    };
  };

  extraConfigLua = ''
    require("colorful-menu").setup()

    -- Patch: stray NUL bytes in item text (e.g. "//" items) raise an error.
    do
      local utils = require("colorful-menu.utils")
      local original = utils.apply_post_processing
      utils.apply_post_processing = function(ci, item, ls)
        if item and item.text then
          item.text = item.text:gsub("%z", "")
        end
        return original(ci, item, ls)
      end
    end
  '';
}
