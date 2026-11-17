# Treesitter with no runtime installation
# Parsers compiled by nix
{
  inputs,
  pkgs,
  lib,
  vp,
  ...
}:

let
  languages = [
    "asm"
    "bash"
    "c"
    "cpp"
    "css"
    "csv"
    "dart"
    "diff"
    "gitcommit"
    "git_config"
    "gitignore"
    "git_rebase"
    "go"
    "html"
    "hyprlang"
    "java"
    "javascript"
    "json"
    "latex"
    "lua"
    "make"
    "markdown"
    "markdown_inline"
    "meson"
    "ninja"
    "nix"
    "odin"
    "pem"
    "python"
    "qmljs"
    "query"
    "ron"
    "rust"
    "scss"
    "sql"
    "toml"
    "tsx"
    "typescript"
    "vim"
    "vimdoc"
    "xml"
    "yaml"
    "zig"
    "zsh"
  ];

  grammars = pkgs.vimPlugins.nvim-treesitter.builtGrammars;

  parserPlugin =
    lang:
    pkgs.runCommand "ts-parser-${lang}" { } ''
      mkdir -p $out/parser
      ln -s ${grammars.${lang}}/parser $out/parser/${lang}.so
    '';

  # Custom language, parser built from the grammar repo, queries from here
  tereixGrammar = pkgs.tree-sitter.buildGrammar {
    language = "tereix";
    version = inputs.nvp-tree-sitter-tereix.shortRev or "git";
    src = inputs.nvp-tree-sitter-tereix;
    # generate = true;  # uncomment if the repo doesnt commit src/parser.c
  };

  tereixPlugin = pkgs.runCommand "ts-parser-tereix" { } ''
    mkdir -p $out/parser $out/queries/tereix
    ln -s ${tereixGrammar}/parser $out/parser/tereix.so
    if [ -d ${tereixGrammar}/queries ]; then
      cp --no-preserve=mode -r ${tereixGrammar}/queries/. $out/queries/tereix/
    fi
  '';

  parsers = pkgs.symlinkJoin {
    name = "nvim-treesitter-parsers";
    paths = map parserPlugin languages ++ [ tereixPlugin ];
  };

  # nvim-treesitter keeps queries in runtime/queries expose them at the plugin root so they land on the runtimepath
  treesitter = vp.nvim-treesitter.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      if [ -d $out/runtime/queries ] && [ ! -e $out/queries ]; then
        ln -s $out/runtime/queries $out/queries
      fi
    '';
  });

  ignoreFiletypes = [
    "alpha"
    "fidget"
    "TelescopePrompt"
    "notify"
    "checkhealth"
    "lspinfo"
    "text"
    "conf"
  ];
in
{
  extraPlugins = [
    treesitter
    parsers
  ];

  autoCmd = [
    {
      event = "FileType";
      pattern = "*";
      callback.__raw = ''
        function(args)
          local ignore = ${lib.nixvim.toLuaObject (lib.genAttrs ignoreFiletypes (_: true))}
          if ignore[vim.bo[args.buf].filetype] or vim.bo[args.buf].buftype ~= "" then
            return
          end
          -- errors (no parser for this filetype) are expected and ignored
          pcall(vim.treesitter.start, args.buf)
        end
      '';
    }
  ];
}
