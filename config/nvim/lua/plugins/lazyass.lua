vim.diagnostic.config({
	virtual_text = {
		source = "if_many",
		prefix = "●",
		spacing = 4,
		update_in_insert = true,
	},
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = " ",
			[vim.diagnostic.severity.WARN] = " ",
			[vim.diagnostic.severity.HINT] = " ",
			[vim.diagnostic.severity.INFO] = " ",
		},
		numhl = {
			[vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
			[vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
			[vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
			[vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
		},
	},
	update_in_insert = true,
	underline = true,
	severity_sort = true,
})

vim.keymap.set("i", "<C-e>", vim.diagnostic.open_float, { noremap = true, silent = true })
vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

-- Force consistent tab settings across all buffers
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.api.nvim_create_autocmd("BufEnter", {
	callback = function()
		vim.opt.tabstop = 2
		vim.opt.softtabstop = 2
		vim.opt.shiftwidth = 2
	end,
})

-- Keep transparency even after colorscheme changes
vim.api.nvim_create_autocmd("ColorScheme", {
	pattern = "*",
	callback = function()
		local groups =
			{ "Normal", "NormalNC", "LineNr", "Folded", "NonText", "SpecialKey", "VertSplit", "SignColumn", "EndOfBuffer" }
		for _, group in ipairs(groups) do
			vim.api.nvim_set_hl(0, group, { bg = "NONE", ctermbg = "NONE" })
		end
		vim.api.nvim_set_hl(0, "GitSignsCurrentLineBlame", { link = "Comment" })
	end,
})

return {
	{
		"folke/tokyonight.nvim",
		lazy = true,
		priority = 1000,
		config = function()
			require("tokyonight").setup({
				style = "night",
				transparent = true,
				terminal_colors = true,
			})
		end,
	},
	{
		"rose-pine/neovim",
		lazy = false,
		name = "rose-pine",
		config = function()
			require("rose-pine").setup({
				variant = "moon",
				dim_inactive_windows = false,
				enable = { terminal = true },
				styles = { transparency = true },
			})
		end,
	},
	{
		"hyperb1iss/silkcircuit-nvim",
		lazy = true,
		priority = 1000,
	},

	{
		"williamboman/mason.nvim",
		config = function()
			require("mason").setup()
		end,
	},

	{
		"L3MON4D3/LuaSnip",
		build = "make install_jsregexp",
	},

	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
			"saghen/blink.cmp",
			"L3MON4D3/LuaSnip",
		},
		config = function()
			local capabilities = require("blink.cmp").get_lsp_capabilities()

			local mod_dirs = {
				vim.fn.expand("~/omods"),
				vim.fn.expand("~/.config/love/Mods"),
			}
			local decomlatro_uri = vim.uri_from_fname(vim.fn.expand("~/decomlatro"))

			local on_attach = function(client, bufnr)
				local opts = { noremap = true, silent = true, buffer = bufnr }
				vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
				vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
				vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, opts)
				vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, opts)
				vim.keymap.set("n", "gr", require("telescope.builtin").lsp_references, opts)

				-- Add source code to workspace if editing a Balatro mod
				if client.name == "lua_ls" then
					local current_file = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
					if current_file ~= "" then
						local in_mod = false
						for _, mod_dir in ipairs(mod_dirs) do
							if current_file:sub(1, #vim.fs.normalize(mod_dir)) == vim.fs.normalize(mod_dir) then
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

			local lsps = {
				"ts_ls",
				"pyright",
				"bashls",
				"rust_analyzer",
				"cssls",
				"html",
				"jsonls",
				"jdtls",
				"gopls",
				"zls",
			}
			if vim.fn.filereadable("/etc/NIXOS") ~= 1 then
				table.insert(lsps, "lua_ls")
				table.insert(lsps, "cmake")
			end

			require("mason-lspconfig").setup({
				ensure_installed = lsps,
				automatic_enable = true,
			})

			for _, server in ipairs(lsps) do
				if vim.lsp.config[server] then
					vim.lsp.enable(server, {
						capabilities = capabilities,
						on_attach = on_attach,
					})
				end
			end

			vim.lsp.enable("lua_ls", {
				capabilities = capabilities,
				on_attach = on_attach,
				settings = {
					Lua = {
						runtime = {
							version = "LuaJIT",
							path = {
								"lua/?.lua",
								"lua/?/init.lua",
							},
						},
						workspace = {
							library = {
								vim.api.nvim_get_runtime_file("", true),
							},
							checkThirdParty = false,
						},
						diagnostics = { globals = { "vim" } },
						telemetry = { enable = false },
						hint = { enable = true },
					},
				},
			})

			vim.lsp.enable("ts_ls", {
				capabilities = capabilities,
				on_attach = on_attach,
				settings = { completions = { completeFunctionCalls = true } },
			})

			-- Standalone LSP setups (not managed by Mason)
			vim.lsp.enable("hyprls", { capabilities = capabilities, on_attach = on_attach })
			vim.lsp.enable("nixd", { capabilities = capabilities, on_attach = on_attach })
			vim.lsp.enable("qmlls", { capabilities = capabilities, on_attach = on_attach, cmd = { "qmlls", "-E" } })
		end,
	},

	{
		"saghen/blink.cmp",
		lazy = false,
		version = "v1.*",
		opts = {
			keymap = {
				preset = "default",
				["<Up>"] = { "select_prev", "fallback" },
				["<Down>"] = { "select_next", "fallback" },
				["<Tab>"] = { "select_and_accept", "fallback" },
			},
			appearance = {
				use_nvim_cmp_as_default = true,
				nerd_font_variant = "mono",
			},
			snippets = { preset = "luasnip" },
			sources = {
				default = { "lsp", "path", "snippets", "buffer" },
			},
			signature = { enabled = true },
		},
	},

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
					"xml",
					"hyprlang",
					"nix",
					"vim",
					"vimdoc",
					"tsx",
					"sql",
					"go",
					"qmljs",
					"zig",
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
				cmd = { "jdtls" },
				root_dir = require("jdtls.setup").find_root({ ".git", "mvnw", "gradlew" }),
			}
			require("jdtls").start_or_attach(config)
		end,
	},

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

	{
		"nvim-lualine/lualine.nvim",
		config = function()
			require("lualine").setup({
				options = {
					theme = "auto",
					component_separators = { left = "", right = "" },
					section_separators = { left = "", right = "" },
					icons_enabled = true,
				},
				sections = {
					lualine_a = { "mode" },
					lualine_b = {
						{ "branch", icon = "" },
						{ "diff", symbols = { added = " ", modified = " ", removed = " " }, colored = false },
						{ "diagnostics", symbols = { error = " ", warn = " ", info = " ", hint = " " } },
					},
					lualine_c = { "filename" },
					lualine_x = {
						{ "encoding", fmt = string.upper },
						{ "fileformat", symbols = { unix = "", dos = "", mac = "" } },
						{ "filetype", icon = { align = "right" } },
					},
					lualine_y = { "progress" },
					lualine_z = { "location" },
				},
			})
		end,
	},

	{
		"goolord/alpha-nvim",
		config = function()
			-- Detect if running in a Nix flake environment or standard config
			local nixenv = os.getenv("NIX_CFG_DIR")
			local base = nixenv == nil and "~/.config" or nixenv .. "/config"

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
				dashboard.button("c", "  Configuration", ":e " .. base .. "/nvim/lua/plugins/lazyass.lua<CR>"),
				dashboard.button("q", "󰈆  Quit Neovim", ":qa<CR>"),
			}
			alpha.setup(dashboard.config)
		end,
	},

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
		dependencies = { "nvim-lua/plenary.nvim", "stevearc/dressing.nvim" },
		config = true,
	},
	{ "nvim-tree/nvim-web-devicons", lazy = true },
	{
		"kdheepak/lazygit.nvim",
		lazy = true,
		cmd = { "LazyGit", "LazyGitConfig", "LazyGitCurrentFile", "LazyGitFilter", "LazyGitFilterCurrentFile" },
		dependencies = { "nvim-lua/plenary.nvim" },
	},
	{ "fladson/vim-kitty", ft = "kitty" },
	{
		"kylechui/nvim-surround",
		event = "VeryLazy",
		config = function()
			require("nvim-surround").setup()
		end,
	},
	{ "j-hui/fidget.nvim", opts = {} },
	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				lua = { "stylua" },
				python = { "ruff_format" },
				rust = { "rustfmt" },
				javascript = { "prettier" },
				typescript = { "prettier" },
				html = { "prettier" },
				css = { "prettier" },
				java = { "google-java-format" },
				c = { "clang-format" },
				cpp = { "clang-format" },
				bash = { "shfmt" },
				zsh = { "shfmt" },
				sh = { "shfmt" },
				json = { "jq" },
				nix = { "nixfmt" },
				go = { "gofmt" },
				zig = { "zigfmt" },
			},
			formatters = {
				stylua = { append_args = { "-a", "--indent-type", "Tabs", "--indent-width", "2" } },
				shfmt = { append_args = { "-ci" } },
			},
		},
	},
}
