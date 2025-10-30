require("config.lazy")


local themes = {
	{ name = "rose-pine", display = "RosePine" },
	{ name = "tokyonight", display = "TokyoNight" },
	{ name = "silkcircuit", display = "silkcircuit" },
}
vim.g.current_theme = 1 -- Start with first theme

local function apply_theme(index)
	vim.g.current_theme = index
	local theme = themes[index]
	vim.cmd.colorscheme(theme.name)
	print("Theme set to: " .. theme.display)
end

local function toggle_theme()
	local next = vim.g.current_theme % #themes + 1
	apply_theme(next)
end

local function set_theme(input)
	local input_lower = input:lower()
	local matches = {}

	-- Find all themes where display name contains input substring (case-insensitive)
	for i, theme in ipairs(themes) do
		if theme.display:lower():find(input_lower, 1, true) then
			table.insert(matches, i)
		end
	end

	-- Handle match results
	if #matches == 0 then
		print("Error: No theme found matching '" .. input .. "'")
	elseif #matches > 1 then
		print("Error: Multiple themes match '" .. input .. "':")
		for _, idx in ipairs(matches) do
			print("  - " .. themes[idx].display)
		end
	else
		apply_theme(matches[1])
	end
end

-- Set initial theme
apply_theme(1)

-- Create commands and keymaps
vim.api.nvim_create_user_command("ToggleTheme", toggle_theme, {})
vim.api.nvim_create_user_command("SetTheme", function(opts) -- NEW command
	set_theme(opts.args)
end, { nargs = 1 })

vim.keymap.set("n", "<leader>tt", toggle_theme, { noremap = true, silent = true, desc = "Toggle color theme" })
