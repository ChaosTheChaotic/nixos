{ ... }:

let
  # vim.diagnostic.severity.X is a Lua expression, so the keys need __rawKey__
  sev = name: "__rawKey__vim.diagnostic.severity.${name}";
in
{
  imports = [
    ./plugins.nix
    ./theme.nix
    ./lsp.nix
    ./completion.nix
    ./treesitter.nix
    ./formatting.nix
    ./ui.nix
    ./tools.nix
  ];

  viAlias = true;
  vimAlias = true;

  globals = {
    mapleader = " ";
    maplocalleader = "\\";
  };

  opts = {
    tabstop = 2;
    shiftwidth = 2;
    softtabstop = 0;
    expandtab = false;
  };

  # Custom language
  filetype.extension = {
    tx = "tereix";
    tereix = "tereix";
  };

  diagnostic.settings = {
    virtual_text = {
      source = "if_many";
      prefix = "●";
      spacing = 4;
    };
    signs = {
      text = {
        ${sev "ERROR"} = " ";
        ${sev "WARN"} = " ";
        ${sev "HINT"} = " ";
        ${sev "INFO"} = " ";
      };
      numhl = {
        ${sev "ERROR"} = "DiagnosticSignError";
        ${sev "WARN"} = "DiagnosticSignWarn";
        ${sev "HINT"} = "DiagnosticSignHint";
        ${sev "INFO"} = "DiagnosticSignInfo";
      };
    };
    update_in_insert = true;
    underline = true;
    severity_sort = true;
    # Toggled with <leader>l (see ui.nix)
    virtual_lines = false;
  };

  keymaps = [
    {
      mode = "i";
      key = "<C-e>";
      action.__raw = "vim.diagnostic.open_float";
      options.silent = true;
    }
  ];
}
