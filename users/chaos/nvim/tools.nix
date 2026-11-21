# Various misc tools
{ pkgs, vp, ... }:

{
  extraPackages = with pkgs; [
    ripgrep # telescope live_grep
    fd # telescope find_files
    lazygit
  ];

  extraPlugins = [
    vp.vim-kitty
    # runtime deps of flutter-tools/telescope/lazygit
    vp.plenary-nvim
    vp.dressing-nvim
  ];

	extraConfigLua = builtins.readFile ./yacht.lua;

  plugins.telescope = {
    enable = true;
    package = vp.telescope-nvim;
    keymaps = {
      "<leader>ff" = "find_files";
      "<leader>fg" = "live_grep";
      "<leader>fb" = "buffers";
      "<leader>fh" = "help_tags";
    };
  };

  plugins.lazygit = {
    enable = true;
    package = vp.lazygit-nvim;
  };

  plugins.nvim-surround = {
    enable = true;
    package = vp.nvim-surround;
  };

  plugins.nvim-autopairs = {
    enable = true;
    package = vp.nvim-autopairs;
    settings = {
      check_ts = true;
      enable_check_bracket_line = false;
      fast_wrap.map = "<M-e>";
    };
  };

  plugins.flutter-tools = {
    enable = true;
    package = vp.flutter-tools-nvim;
  };
}
