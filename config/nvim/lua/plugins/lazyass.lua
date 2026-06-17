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

vim.filetype.add({
	extension = {
		tx = "tereix",
		tereix = "tereix",
	},
})

table.contains = function(t, v)
	for _, val in ipairs(t) do
		if val == v then
			return true
		end
	end
	return false
end

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
		dependencies = {
			"rafamadriz/friendly-snippets",
		},
		config = function()
			require("luasnip.loaders.from_vscode").lazy_load()
		end,
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
				vim.fn.expand("~/.local/share/Balatro/Mods"),
			}
			local decomlatro_uri = vim.uri_from_fname(vim.fn.expand("~/decomlatro"))

			local on_attach = function(_, bufnr)
				local opts = { noremap = true, silent = true, buffer = bufnr }
				vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
				vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
				vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, opts)
				vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, opts)
				vim.keymap.set("n", "gr", require("telescope.builtin").lsp_references, opts)
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
				table.insert(lsps, "clangd")
			end

			require("mason-lspconfig").setup({
				ensure_installed = lsps,
				handlers = {
					function(server_name)
						vim.lsp.enable(server_name)
					end,
				},
			})

			vim.lsp.config("*", {
				capabilities = capabilities,
				on_attach = on_attach,
			})

			vim.lsp.enable(lsps)

			if not table.contains(lsps, "lua_ls") then
				-- The only possible way we can be in here is if we are on nixos
				local hypr_stubs = "/run/current-system/sw/share/hypr/stubs"
				vim.lsp.config("lua_ls", {
					capabilities = capabilities,
					on_attach = function(client, bufnr)
						if on_attach then
							on_attach(client, bufnr)
						end

						local fpth = vim.api.nvim_buf_get_name(bufnr)
						if fpth == "" then
							return
						end

						local hmatch = false
						local vmatch = false
						for d in vim.fs.parents(fpth) do
							local bname = vim.fs.basename(d)
							if bname == "hypr" or bname == "hyprland" then
								hmatch = true
							end
							if bname == "nvim" or bname == "vim" then
								vmatch = true
							end
						end

						local currLibs = vim.deepcopy(client.settings.Lua.workspace.library or {})
						local currGlobals = vim.deepcopy(client.settings.Lua.diagnostics.globals or {})
						local changed = false

						if hmatch and vim.fn.isdirectory(hypr_stubs) == 1 then
							if not vim.tbl_contains(currLibs, hypr_stubs) then
								table.insert(currLibs, hypr_stubs)
								changed = true
							end
							if not vim.tbl_contains(currGlobals, "hl") then
								table.insert(currGlobals, "hl")
								changed = true
							end
						end

						if vmatch then
							if not vim.tbl_contains(currLibs, vim.env.VIMRUNTIME) then
								table.insert(currLibs, vim.env.VIMRUNTIME)
								changed = true
							end
							if not vim.tbl_contains(currGlobals, "vim") then
								table.insert(currGlobals, "vim")
								changed = true
							end
						end

						if changed then
							client.settings = vim.tbl_deep_extend("force", client.settings, {
								Lua = { workspace = { library = currLibs } },
							})
							client:notify("workspace/didChangeConfiguration", { settings = client.settings })
						end

						-- Add source code to workspace if editing a Balatro mod
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
					end,
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
								library = {},
								checkThirdParty = false,
							},
							diagnostics = { globals = {} },
							telemetry = { enable = false },
							hint = { enable = true },
						},
					},
				})

				vim.lsp.enable("lua_ls")
			end

			vim.lsp.config("ts_ls", {
				capabilities = capabilities,
				on_attach = on_attach,
				settings = {
					completions = { completeFunctionCalls = true },
				},
			})

			vim.lsp.config("hyprls", {
				capabilities = capabilities,
				on_attach = on_attach,
			})

			vim.lsp.config("nixd", {
				capabilities = capabilities,
				on_attach = on_attach,
			})

			vim.lsp.config("qmlls", {
				capabilities = capabilities,
				on_attach = on_attach,
				cmd = { "qmlls", "-E" },
			})

			vim.lsp.enable({ "ts_ls", "hyprls", "nixd", "qmlls" })
			if not table.contains(lsps, "clangd") then
				vim.lsp.config("clangd", {
					capabilities = capabilities,
					on_attach = on_attach,
					cmd = { "clangd", "--background-index", "--clang-tidy" },
				})
				vim.lsp.enable("clangd")
			end
			if not table.contains(lsps, "cmake") then
				vim.lsp.config("cmake", {
					capabilities = capabilities,
					on_attach = on_attach,
					cmd = { "cmake-language-server" },
					init_options = {
						buildDirectory = "build",
					},
				})
				vim.lsp.enable("cmake")
			end
			vim.lsp.config("tereix", {
				cmd = { "tereix", "--lsp" },
				filetypes = { "tereix" },
				root_markers = { ".git" },
				capabilities = capabilities,
				on_attach = on_attach,
			})

			vim.lsp.enable("tereix")
		end,
	},

	{
		"xzbdmw/colorful-menu.nvim",
		config = function()
			require("colorful-menu").setup()

			local utils = require("colorful-menu.utils")
			local original = utils.apply_post_processing
			utils.apply_post_processing = function(ci, item, ls)
				if item and item.text then
					item.text = item.text:gsub("%z", "") -- Patch "//" triggering an error
				end
				return original(ci, item, ls)
			end
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
			completion = {
				documentation = {
					auto_show = true,
					auto_show_delay_ms = 10,
				},
				menu = {
					draw = {
						-- We don't need label_description now because label and label_description are already
						-- combined together in label by colorful-menu.nvim.
						columns = { { "kind_icon" }, { "label", gap = 1 } },
						components = {
							label = {
								text = function(ctx)
									return require("colorful-menu").blink_components_text(ctx)
								end,
								highlight = function(ctx)
									return require("colorful-menu").blink_components_highlight(ctx)
								end,
							},
						},
					},
				},
			},
		},
	},

	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		build = ":TSUpdate",
		lazy = false,
		config = function()
			vim.api.nvim_create_autocmd("User", {
				pattern = "TSUpdate",
				callback = function()
					require("nvim-treesitter.parsers").tereix = {
						install_info = {
							url = "https://github.com/ChaosTheChaotic/tree-sitter-tereix",
							branch = "master",
						},
					}
				end,
			})

			require("nvim-treesitter").install({
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
				"markdown_inline",
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
				"diff",
				"tereix",
				"make",
				"gitcommit",
				"meson",
				"ninja",
			})

			vim.api.nvim_create_autocmd("FileType", {
				pattern = "*",
				callback = function(args)
					local bufnr = args.buf
					local ft = vim.bo[bufnr].filetype

					local ignore_ft = {
						"alpha",
						"fidget",
						"TelescopePrompt",
						"notify",
						"lazy",
						"mason",
						"lspinfo",
						"checkhealth",
						"text",
					}
					for _, name in ipairs(ignore_ft) do
						if ft == name then
							return
						end
					end

					if vim.bo[bufnr].buftype ~= "" then
						return
					end

					local lang = vim.treesitter.language.get_lang(ft) or ft
					local has_parser = pcall(vim.treesitter.get_parser, bufnr, lang)

					if has_parser then
						vim.treesitter.start(bufnr, lang)
					end
				end,
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
				tereix = { "tx_fmt" },
			},
			formatters = {
				stylua = { append_args = { "-a", "--indent-type", "Tabs", "--indent-width", "2" } },
				shfmt = { append_args = { "-ci" } },
				tx_fmt = {
					command = "tereix",
					args = { "fmt", "-w", "$FILENAME" },
					stdin = false,
				},
			},
		},
	},
}
