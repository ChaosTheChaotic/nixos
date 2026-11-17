{
  description = "Nixvim config and plugins";
  inputs = {
    # Only here so the follows below resolve
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    blink-cmp = {
      url = "github:saghen/blink.cmp";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # All nvp-* should be picked up by nixvim
    nvp-tokyonight-nvim = {
      url = "github:folke/tokyonight.nvim";
      flake = false;
    };
    nvp-rose-pine = {
      url = "github:rose-pine/neovim";
      flake = false;
    };
    nvp-silkcircuit-nvim = {
      url = "github:hyperb1iss/silkcircuit-nvim";
      flake = false;
    };
    nvp-friendly-snippets = {
      url = "github:rafamadriz/friendly-snippets";
      flake = false;
    };
    nvp-nvim-lspconfig = {
      url = "github:neovim/nvim-lspconfig";
      flake = false;
    };
    nvp-colorful-menu-nvim = {
      url = "github:xzbdmw/colorful-menu.nvim";
      flake = false;
    };
    nvp-nvim-treesitter = {
      url = "github:nvim-treesitter/nvim-treesitter/main";
      flake = false;
    };
    nvp-tree-sitter-tereix = {
      url = "github:ChaosTheChaotic/tree-sitter-tereix";
      flake = false;
    };
    nvp-plenary-nvim = {
      url = "github:nvim-lua/plenary.nvim";
      flake = false;
    };
    nvp-telescope-nvim = {
      url = "github:nvim-telescope/telescope.nvim";
      flake = false;
    };
    nvp-gitsigns-nvim = {
      url = "github:lewis6991/gitsigns.nvim";
      flake = false;
    };
    nvp-lualine-nvim = {
      url = "github:nvim-lualine/lualine.nvim";
      flake = false;
    };
    nvp-alpha-nvim = {
      url = "github:goolord/alpha-nvim";
      flake = false;
    };
    nvp-nvim-autopairs = {
      url = "github:windwp/nvim-autopairs";
      flake = false;
    };
    nvp-lsp-lines-nvim = {
      url = "git+https://git.sr.ht/~whynothugo/lsp_lines.nvim";
      flake = false;
    };
    nvp-flutter-tools-nvim = {
      url = "github:nvim-flutter/flutter-tools.nvim";
      flake = false;
    };
    nvp-dressing-nvim = {
      url = "github:stevearc/dressing.nvim";
      flake = false;
    };
    nvp-nvim-web-devicons = {
      url = "github:nvim-tree/nvim-web-devicons";
      flake = false;
    };
    nvp-lazygit-nvim = {
      url = "github:kdheepak/lazygit.nvim";
      flake = false;
    };
    nvp-vim-kitty = {
      url = "github:fladson/vim-kitty";
      flake = false;
    };
    nvp-nvim-surround = {
      url = "github:kylechui/nvim-surround";
      flake = false;
    };
    nvp-fidget-nvim = {
      url = "github:j-hui/fidget.nvim";
      flake = false;
    };
    nvp-conform-nvim = {
      url = "github:stevearc/conform.nvim";
      flake = false;
    };
    nvp-nvim-colorizer-lua = {
      url = "github:catgoose/nvim-colorizer.lua";
      flake = false;
    };
  };

  outputs =
    { nixvim, ... }@inputs:
    {
      lib.mkNvim =
        {
          pkgs,
          master,
          tereix,
          balatroLsp ? false,
          balatroExe ? null, # when null, decomlatro.nix uses requireFile
        }:
        let
          decomlatro = if balatroLsp then pkgs.callPackage ./decomlatro.nix { inherit balatroExe; } else null;
        in
        nixvim.legacyPackages.${pkgs.stdenv.hostPlatform.system}.makeNixvimWithModule {
          inherit pkgs;
          module = ./default.nix;
          extraSpecialArgs = {
            inherit
              inputs
              master
              tereix
              decomlatro
              ;
          };
        };
    };
}
