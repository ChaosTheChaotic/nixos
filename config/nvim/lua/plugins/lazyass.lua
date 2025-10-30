-- Global diagnostic config (TokyoNight colors will handle styling)
vim.diagnostic.config({
	virtual_text = {
		source = "if_many", -- Only show virtual text if multiple diagnostics
		prefix = "●",
		spacing = 4,
		update_in_insert = true, -- Enable updates in insert mode
	},
	signs = true,
	update_in_insert = true,
	underline = true,
	severity_sort = true,
})
vim.keymap.set("i", "<C-e>", vim.diagnostic.open_float, { noremap = true, silent = true })

-- Custom signs for diagnostics
local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
for type, icon in pairs(signs) do
	local hl = "DiagnosticSign" .. type
	vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

vim.opt.tabstop = 8
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2

return {
	{
		"folke/tokyonight.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			require("tokyonight").setup({
				style = "night",
				transparent = true, -- Changed to true
				terminal_colors = true,
			})
			--vim.cmd([[colorscheme tokyonight]])
			-- Add transparency to specific groups
			vim.cmd([[
	        highlight Normal guibg=NONE ctermbg=NONE
	        highlight NormalNC guibg=NONE ctermbg=NONE
	        highlight LineNr guibg=NONE ctermbg=NONE
	        highlight Folded guibg=NONE ctermbg=NONE
	        highlight NonText guibg=NONE ctermbg=NONE
	        highlight SpecialKey guibg=NONE ctermbg=NONE
	        highlight VertSplit guibg=NONE ctermbg=NONE
	        highlight SignColumn guibg=NONE ctermbg=NONE
	        highlight EndOfBuffer guibg=NONE ctermbg=NONE
	      ]])
		end,
	},
	{
		"rose-pine/neovim",
		lazy = true,
		name = "rose-pine",
		config = function()
			require("rose-pine").setup({
				variant = "moon",
				dim_inactive_windows = false,
				enable = {
					terminal = true,
				},
				styles = {
					transparency = true,
				},
			})
			--vim.cmd("colorscheme rose-pine")

			vim.cmd([[
        highlight Normal guibg=NONE ctermbg=NONE
        highlight NormalNC guibg=NONE ctermbg=NONE
        highlight LineNr guibg=NONE ctermbg=NONE
        highlight Folded guibg=NONE ctermbg=NONE
        highlight NonText guibg=NONE ctermbg=NONE
        highlight SpecialKey guibg=NONE ctermbg=NONE
        highlight VertSplit guibg=NONE ctermbg=NONE
        highlight SignColumn guibg=NONE ctermbg=NONE
        highlight EndOfBuffer guibg=NONE ctermbg=NONE
      ]])
		end,
	},
	{
	  "hyperb1iss/silkcircuit-nvim",
	  lazy = true,
	  priority = 1000,
	  config = function()
	    --vim.cmd.colorscheme("silkcircuit")
	    vim.cmd([[
	      highlight Normal guibg=NONE ctermbg=NONE
              highlight NormalNC guibg=NONE ctermbg=NONE
              highlight LineNr guibg=NONE ctermbg=NONE
              highlight Folded guibg=NONE ctermbg=NONE
              highlight NonText guibg=NONE ctermbg=NONE
              highlight SpecialKey guibg=NONE ctermbg=NONE
              highlight VertSplit guibg=NONE ctermbg=NONE
              highlight SignColumn guibg=NONE ctermbg=NONE
              highlight EndOfBuffer guibg=NONE ctermbg=NONE
	    ]])
	  end,
	},

	-- Package Management
	{
		"williamboman/mason.nvim",
		config = function()
			require("mason").setup()
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = {
					"lua_ls",
					"ts_ls",
					"pyright",
					"bashls",
					"rust_analyzer",
					"cssls",
					"html",
					"jsonls",
					"cmake",
					"jdtls",
				},
				automatic_installation = true,
			})
		end,
	},

	-- LSP Configuration
	{
	  "neovim/nvim-lspconfig",
	  dependencies = {
	    "hrsh7th/nvim-cmp",
	    "hrsh7th/cmp-nvim-lsp",
	    "hrsh7th/cmp-buffer",
	    "hrsh7th/cmp-path",
	    "L3MON4D3/LuaSnip",
	  },
	  config = function()
	    local capabilities = require("cmp_nvim_lsp").default_capabilities()
	    -- For balatro
	    local mod_dirs = {
	      vim.fn.expand("~/omods"),
	      vim.fn.expand("~/.config/love/Mods"),
	    }
	    local decomlatro_uri = vim.uri_from_fname(vim.fn.expand("~/decomlatro"))
	    
	    -- Enhanced LSP mappings
	    local on_attach = function(client, bufnr)
	      local opts = { noremap = true, silent = true, buffer = bufnr }
	      vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
	      vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
	      vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, opts)
	      vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, opts)
	      vim.keymap.set("n", "gr", require("telescope.builtin").lsp_references, opts)
	      
	      -- Conditionally add decomlatro to workspace for lua_ls
	      if client.name == "lua_ls" then
	        local current_file = vim.api.nvim_buf_get_name(bufnr)
	        if current_file ~= "" then
	          current_file = vim.fs.normalize(current_file)
	          local in_mod = false
	          for _, mod_dir in ipairs(mod_dirs) do
	            mod_dir = vim.fs.normalize(mod_dir)
	            if current_file:sub(1, #mod_dir) == mod_dir then
	              in_mod = true
	              break
	            end
	          end
	          if in_mod then
	            local has_decomlatro = false
	            for _, folder in ipairs(client.workspace_folders or {}) do
	              if folder.uri == decomlatro_uri then
	                has_decomlatro = true
	                break
	              end
	            end
	            if not has_decomlatro then
	              vim.lsp.buf.add_workspace_folder(decomlatro_uri)
	            end
	          end
	        end
	      end
	    end
	
	    -- File type to LSP server mapping
	    local servers = {
	      lua = {
	        name = "lua_ls",
	        cmd = { "lua-language-server" },
	        settings = {
	          Lua = {
	            runtime = { version = "Lua 5.4.8" },
	            workspace = {
	              library = vim.api.nvim_get_runtime_file("", true),
	              checkThirdParty = false,
	            },
	            diagnostics = { globals = { "vim" } },
	            telemetry = { enable = false },
	          },
	        },
	      },
	      typescript = {
	        name = "tsserver",
	        cmd = { "typescript-language-server", "--stdio" },
	        settings = {
	          completions = { completeFunctionCalls = true },
	          javascript = { preferences = { importModuleSpecifier = "relative" } },
	          typescript = { preferences = { importModuleSpecifier = "relative" } },
	        },
	      },
	      javascript = {
	        name = "tsserver",
	        cmd = { "typescript-language-server", "--stdio" },
	      },
	      python = {
	        name = "pyright",
	        cmd = { "pyright-langserver", "--stdio" },
	      },
	      sh = {
	        name = "bashls",
	        cmd = { "bash-language-server", "start" },
	      },
	      rust = {
	        name = "rust_analyzer",
	        cmd = { "rust-analyzer" },
	        root_dir = function(fname)
	          -- Only start rust-analyzer if there's a Cargo.toml file
	          local cargo = vim.fn.findfile("Cargo.toml", vim.fn.fnamemodify(fname, ":h") .. ";")
	          return cargo ~= "" and vim.fn.fnamemodify(cargo, ":h") or nil
	        end,
	      },
	      c = {
	        name = "clangd",
	        cmd = { "clangd", "--background-index", "--clang-tidy" },
	      },
	      cpp = {
	        name = "clangd",
	        cmd = { "clangd", "--background-index", "--clang-tidy" },
	      },
	      nix = {
	        name = "nixd",
	        cmd = { "nixd" },
	      },
	    }

	    -- Autostart LSP servers based on filetype
	    vim.api.nvim_create_autocmd("FileType", {
	      pattern = vim.tbl_keys(servers),
	      callback = function(ev)
	        local server = servers[ev.match]
	        if server then
	          -- Check if we need a root directory and if it exists
	          if server.root_dir then
	            local root = server.root_dir(ev.file)
	            if not root then
	              return
	            end
	          end
	          
	          -- Start the language server
	          vim.lsp.start({
	            name = server.name,
	            cmd = server.cmd,
	            capabilities = capabilities,
	            on_attach = on_attach,
	            settings = server.settings,
	            root_dir = server.root_dir and server.root_dir(ev.file) or nil,
	          })
	        end
	      end,
	    })
	  end,
	},

	-- Completion Engine
	{
		"hrsh7th/nvim-cmp",
		config = function()
			local cmp = require("cmp")
			cmp.setup({
				snippet = {
					expand = function(args)
						require("luasnip").lsp_expand(args.body)
					end,
				},
				mapping = cmp.mapping.preset.insert({
					["<C-b>"] = cmp.mapping.scroll_docs(-4),
					["<C-f>"] = cmp.mapping.scroll_docs(4),
					["<C-Space>"] = cmp.mapping.complete(),
					["<C-e>"] = cmp.mapping.abort(),
					["<Tab>"] = cmp.mapping.confirm({ select = true }),
					["<Up>"] = cmp.mapping.select_prev_item(), -- Arrow navigation
					["<Down>"] = cmp.mapping.select_next_item(),
				}),
				sources = cmp.config.sources({
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
					{ name = "buffer" },
					{ name = "path" },
				}),
			})
		end,
	},

	-- Treesitter
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter.configs").setup({
				ensure_installed = {
					"c",
					"cpp",
					"rust",
					"python",
					"lua",
					"bash",
					"typescript",
					"javascript",
					"json",
					"html",
					"css",
					"markdown",
					"toml",
					"dart",
					"java",
				},
				highlight = { enable = true },
				indent = { enable = true },
				autotag = { enable = true },
			})
		end,
	},
	{
	    "mfussenegger/nvim-jdtls",
	    ft = "java",
	    config = function()
	        local config = {
	            cmd = {'jdtls'},
	            root_dir = require('jdtls.setup').find_root({'.git', 'mvnw', 'gradlew'}),
	        }
	        require('jdtls').start_or_attach(config)
	    end
	},

	-- Telescope
	{
		"nvim-telescope/telescope.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			require("telescope").setup()
			local builtin = require("telescope.builtin")
			vim.keymap.set("n", "<leader>ff", builtin.find_files, {})
			vim.keymap.set("n", "<leader>fg", builtin.live_grep, {})
			vim.keymap.set("n", "<leader>fb", builtin.buffers, {})
			vim.keymap.set("n", "<leader>fh", builtin.help_tags, {})
		end,
	},

	-- Git Integration
	{
		"lewis6991/gitsigns.nvim",
		config = function()
			require("gitsigns").setup({
				signs = {
					add = { text = "+" },
					change = { text = "~" },
					delete = { text = "_" },
					topdelete = { text = "‾" },
					changedelete = { text = "~" },
				},
				current_line_blame = true,
			})
			vim.keymap.set("n", "<leader>gb", ":Gitsigns toggle_current_line_blame<CR>")
		end,
	},

	-- Status Line
	{
		"nvim-lualine/lualine.nvim",
		config = function()
			require("lualine").setup({
				options = {
					theme = "tokyonight",
					component_separators = { left = "", right = "" },
					section_separators = { left = "", right = "" },
					icons_enabled = true,
				},
				sections = {
					lualine_a = { "mode" },
					lualine_b = {
						{ "branch", icon = "" },
						{
							"diff",
							symbols = { added = " ", modified = " ", removed = " " },
							colored = false,
						},
						{
							"diagnostics",
							symbols = { error = " ", warn = " ", info = " ", hint = " " },
						},
					},
					lualine_c = { "filename" },
					lualine_x = {
						{ "encoding", fmt = string.upper },
						{ "fileformat", symbols = { unix = "", dos = "", mac = "" } },
						{ "filetype", icon = { align = "right" } },
					},
					lualine_y = { "progress" },
					lualine_z = { "location" },
				},
			})
		end,
	},

	-- Startup Screen
	{
		"goolord/alpha-nvim",
		config = function()
			local alpha = require("alpha")
			local dashboard = require("alpha.themes.dashboard")
			dashboard.section.header.val = {
				[[                                                                     ]],
				[[       ████ ██████           █████      ██                     ]],
				[[      ███████████             █████                             ]],
				[[      █████████ ███████████████████ ███   ███████████   ]],
				[[     █████████  ███    █████████████ █████ ██████████████   ]],
				[[    █████████ ██████████ █████████ █████ █████ ████ █████   ]],
				[[  ███████████ ███    ███ █████████ █████ █████ ████ █████  ]],
				[[ ██████  █████████████████████ ████ █████ █████ ████ ██████ ]],
			}
			dashboard.section.buttons.val = {
				dashboard.button("e", "  New file", ":ene <BAR> startinsert <CR>"),
				dashboard.button("f", "󰈞  Find file", ":Telescope find_files<CR>"),
				dashboard.button("r", "  Recent files", ":Telescope oldfiles<CR>"),
				dashboard.button("l", "󰒲  Lazy", ":Lazy<CR>"),
				dashboard.button("m", "󱁤  Mason", ":Mason<CR>"),
				dashboard.button("g", "  LazyGit", ":LazyGit<CR>"),
				dashboard.button("c", "  Configuration", ":e ~/.config/nvim/lua/plugins/lazyass.lua<CR>"),
				dashboard.button("q", "󰈆  Quit Neovim", ":qa<CR>"),
			}
			alpha.setup(dashboard.config)
		end,
	},

	-- Auto Pairs
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = function()
			require("nvim-autopairs").setup({
				check_ts = true,
				enable_check_bracket_line = false,
				fast_wrap = { map = "<M-e>" },
			})
		end,
	},

	-- Additional Diagnostics
	{
		"https://git.sr.ht/~whynothugo/lsp_lines.nvim",
		config = function()
			require("lsp_lines").setup()
			vim.diagnostic.config({ virtual_lines = false })
			vim.keymap.set("", "<Leader>l", function()
				vim.diagnostic.config({ virtual_lines = not vim.diagnostic.config().virtual_lines })
			end, { desc = "Toggle LSP lines" })
		end,
	},
	{
		"nvim-flutter/flutter-tools.nvim",
		lazy = false,
		dependencies = {
			"nvim-lua/plenary.nvim",
			"stevearc/dressing.nvim", -- optional for vim.ui.select
		},
		config = true,
	},
	{
		"nvim-tree/nvim-web-devicons",
		lazy = true,
	},
	{
		"kdheepak/lazygit.nvim",
		lazy = true,
		cmd = {
			"LazyGit",
			"LazyGitConfig",
			"LazyGitCurrentFile",
			"LazyGitFilter",
			"LazyGitFilterCurrentFile",
		},
		-- optional for floating window border decoration
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
	},
	{
		"fladson/vim-kitty",
		ft = "kitty",
	},
}
