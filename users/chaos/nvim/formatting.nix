{
  pkgs,
  master,
  tereix,
  vp,
  ...
}:

{
  extraPackages = with pkgs; [
    stylua
    ruff
    kdePackages.qtdeclarative # qmlformat
    prettier
    google-java-format
    clang-tools # clang-format
    shfmt
    jq
    nixfmt
    master.ols # odinfmt
    tereix
    # gofmt/zig fmt come from go/zig (lsp.nix). rustfmt from rustup
  ];

  plugins.conform-nvim = {
    enable = true;
    package = vp.conform-nvim;
    settings = {
      formatters_by_ft = {
        lua = [ "stylua" ];
        python = [ "ruff_format" ];
        qml = [ "qmlformat" ];
        rust = [ "rustfmt" ];
        javascript = [ "prettier" ];
        typescript = [ "prettier" ];
        html = [ "prettier" ];
        css = [ "prettier" ];
        java = [ "google-java-format" ];
        c = [ "clang-format" ];
        cpp = [ "clang-format" ];
        bash = [ "shfmt" ];
        zsh = [ "shfmt" ];
        sh = [ "shfmt" ];
        json = [ "jq" ];
        nix = [ "nixfmt" ];
        go = [ "gofmt" ];
        zig = [ "zigfmt" ];
        odin = [ "odinfmt" ];
        tereix = [ "tx_fmt" ];
      };
      formatters = {
        stylua.append_args = [
          "-a"
          "--indent-type"
          "Tabs"
          "--indent-width"
          "2"
        ];
        shfmt.append_args = [ "-ci" ];
        qmlformat.append_args = [
          "-t"
          "-n"
          "--objects-spacing"
          "--functions-spacing"
          "--single-line-empty-objects"
        ];
        tx_fmt = {
          command = "tereix";
          args = [
            "fmt"
            "-w"
            "$FILENAME"
          ];
          stdin = false;
        };
      };
      # gq (via formatexpr) falls back to the LSP when no formatter matches
      default_format_opts.lsp_format = "fallback";
    };
  };

  # gq uses conform
  opts.formatexpr = "v:lua.require'conform'.formatexpr()";

  # Explicit format key
  keymaps = [
    {
      mode = [
        "n"
        "v"
      ];
      key = "<leader>cf";
      action.__raw = "function() require('conform').format({ async = true }) end";
      options.desc = "Format buffer / selection";
    }
  ];
}
