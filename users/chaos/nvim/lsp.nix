{
  config,
  lib,
  pkgs,
  master,
  tereix,
  decomlatro,
  vp,
  ...
}:

let
  toLua = lib.nixvim.toLuaObject;

  lspKey = key: action: desc: {
    inherit key;
    lspBufAction = action;
    options = {
      silent = true;
      inherit desc;
    };
  };

  luaProfiles = [
    {
      # Hyprlands lua config
      dirNames = [
        "hypr"
        "hyprland"
      ];
      library = [ "/run/current-system/sw/share/hypr/stubs" ];
      globals = [ "hl" ];
    }
    {
      # Neovim lua (any dir called nvim/vim)
      dirNames = [
        "nvim"
        "vim"
      ];
      library = [ "${config.package}/share/nvim/runtime" ];
      globals = [ "vim" ];
    }
  ]
  ++ lib.optional (decomlatro != null) {
    # Balatro mods, unpacked game sources as a read only library
    pathPrefixes = [
      "~/.local/share/Balatro/Mods"
      "$NIX_CFG_DIR/users/chaos/balatro/mods"
    ];
    library = [ "${decomlatro}" ];
    globals = [ ];
  };
in
{
  plugins.lspconfig = {
    enable = true;
    package = vp.nvim-lspconfig;
  };

  # Tools the servers/formatters fork out to
  extraPackages = with pkgs; [
    typescript # tsserver for ts_ls
    shellcheck # used by bashls
    go # gopls + gofmt need the go tool
    zig # zigfmt
    master.odin # ols
  ];

  lsp = {
    keymaps = [
      (lspKey "gd" "definition" "Go to definition")
      # Buffer local, so plain gf still works in buffers without an LSP
      (lspKey "gf" "definition" "Smart go-to-definition (LSP first)")
      (lspKey "K" "hover" "Hover")
      (lspKey "<leader>lr" "rename" "Rename")
      (lspKey "<leader>la" "code_action" "Code action")
      {
        key = "gr";
        action = "<cmd>Telescope lsp_references<CR>";
        options = {
          silent = true;
          desc = "References";
        };
      }
    ];

    servers = {
      "*".config.capabilities.__raw = "require('blink.cmp').get_lsp_capabilities()";

      ts_ls = {
        enable = true;
        package = pkgs.typescript-language-server;
        config.settings.completions.completeFunctionCalls = true;
      };
      pyright = {
        enable = true;
        package = pkgs.pyright;
      };
      bashls = {
        enable = true;
        package = pkgs.bash-language-server;
      };
      # Toolchain (rustc/cargo/rustfmt/rust-src) still comes from rustup
      rust_analyzer = {
        enable = true;
        package = pkgs.rust-analyzer;
      };
      cssls = {
        enable = true;
        package = pkgs.vscode-langservers-extracted;
      };
      html = {
        enable = true;
        package = pkgs.vscode-langservers-extracted;
      };
      jsonls = {
        enable = true;
        package = pkgs.vscode-langservers-extracted;
      };
      jdtls = {
        enable = true;
        package = pkgs.jdt-language-server;
      };
      gopls = {
        enable = true;
        package = pkgs.gopls;
      };
      zls = {
        enable = true;
        package = pkgs.zls;
      };
      hyprls = {
        enable = true;
        package = pkgs.hyprls;
      };
      nixd = {
        enable = true;
        package = pkgs.nixd;
      };
      ols = {
        enable = true;
        package = master.ols;
      };

      cmake = {
        enable = true;
        package = pkgs.cmake-language-server;
        config.init_options.buildDirectory = "build";
      };

      clangd = {
        enable = true;
        package = pkgs.clang-tools;
        config.cmd = [
          "clangd"
          "--background-index"
          "--clang-tidy"
        ];
      };

      qmlls = {
        enable = true;
        package = pkgs.kdePackages.qtdeclarative;
        config.cmd = [
          "qmlls"
          "-E"
        ];
      };

      # Custom language
      tereix = {
        enable = true;
        package = tereix;
        config = {
          cmd = [
            "tereix"
            "--lsp"
          ];
          filetypes = [ "tereix" ];
          root_markers = [ ".git" ];
        };
      };

      lua_ls = {
        enable = true;
        package = pkgs.lua-language-server;
        config = {
          settings.Lua = {
            runtime = {
              version = "LuaJIT";
              path = [
                "lua/?.lua"
                "lua/?/init.lua"
              ];
            };
            workspace = {
              library = [ ];
              checkThirdParty = false;
            };
            diagnostics.globals = [ ];
            telemetry.enable = false;
            hint.enable = true;
          };

          # Adds libraries/globals depending on where the buffer lives
          # This is the one piece of real logic that can't be expressed as plain settings
          # The data it uses is luaProfiles above.
          on_attach.__raw = ''
            (function()
              local profiles = ${toLua luaProfiles}
              return function(client, bufnr)
                local path = vim.api.nvim_buf_get_name(bufnr)
                if path == "" then
                  return
                end
                path = vim.fs.normalize(path)

                local names = {}
                for dir in vim.fs.parents(path) do
                  names[vim.fs.basename(dir)] = true
                end

                local lua = client.settings.Lua
                local library = vim.deepcopy(lua.workspace.library or {})
                local globals = vim.deepcopy(lua.diagnostics.globals or {})
                local changed = false

                local function add(list, items)
                  for _, item in ipairs(items or {}) do
                    if not vim.tbl_contains(list, item) then
                      table.insert(list, item)
                      changed = true
                    end
                  end
                end

                for _, p in ipairs(profiles) do
                  local hit = false
                  for _, name in ipairs(p.dirNames or {}) do
                    hit = hit or names[name] == true
                  end
                  for _, prefix in ipairs(p.pathPrefixes or {}) do
                    hit = hit or vim.startswith(path, vim.fs.normalize(prefix))
                  end
                  if hit then
                    add(library, p.library)
                    add(globals, p.globals)
                  end
                end

                if changed then
                  client.settings = vim.tbl_deep_extend("force", client.settings, {
                    Lua = { workspace = { library = library }, diagnostics = { globals = globals } },
                  })
                  client:notify("workspace/didChangeConfiguration", { settings = client.settings })
                end
              end
            end)()
          '';
        };
      };
    };
  };
}
