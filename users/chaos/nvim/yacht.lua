-- Recipe: add to your neovim config (nixvim: `extraConfigLua`).
--
-- Bare TTY only (no WAYLAND_DISPLAY/DISPLAY), so neovim finds no wl-copy/xclip.
--   copy : OSC 52 (the terminal sets its own clipboard) and `yacht copy`, so
--          the yacht history, which paste reads, includes what you just yanked
--          even when nvim is not running under `yacht wrap`.
--   paste: newest yacht entry, text or image, whatever it is. Neovim's OSC 52
--          *paste* needs a terminal query round trip and times out on many
--          terminals, so we avoid it.
-- Needs neovim >= 0.10 (vim.ui.clipboard.osc52, vim.system).
--
-- Text pastes exactly. Binary (an image) goes through neovim's line model, so
-- it is not guaranteed byte-exact (NULs, trailing newline); use :YachtSave
-- for an exact copy of the newest entry.
if vim.env.WAYLAND_DISPLAY == nil and vim.env.DISPLAY == nil then
	local osc52 = require("vim.ui.clipboard.osc52")

	local function copy(reg)
		local to_terminal = osc52.copy(reg)
		return function(lines, regtype)
			to_terminal(lines, regtype)
			local text = table.concat(lines, "\n")
			if regtype == "V" then
				text = text .. "\n"
			end
			-- Async; pcall in case yacht is not installed.
			pcall(vim.system, { "yacht", "copy", "--source", "nvim" }, { stdin = text })
		end
	end

	local function paste()
		-- stdout is a pipe here, so `yacht paste` emits raw bytes for any type.
		local ok, r = pcall(function()
			return vim.system({ "yacht", "paste" }, { text = false }):wait(3000)
		end)
		if not ok or r.code ~= 0 or not r.stdout or r.stdout == "" then
			return { { "" }, "v" }
		end
		local out, regtype = r.stdout, "v"
		if out:sub(-1) == "\n" then
			out, regtype = out:sub(1, -2), "V"
		end
		return { vim.split(out, "\n", { plain = true }), regtype }
	end

	vim.g.clipboard = {
		name = "osc52+yacht",
		copy = { ["+"] = copy("+"), ["*"] = copy("*") },
		paste = { ["+"] = paste, ["*"] = paste },
	}

	-- :YachtSave path  -> write the newest entry (text or image) byte-exact.
	vim.api.nvim_create_user_command("YachtSave", function(o)
		local r = vim.system({ "yacht", "paste", "-o", o.args }):wait()
		if r.code ~= 0 then
			vim.notify(vim.trim(r.stderr or "yacht paste failed"), vim.log.levels.ERROR)
		end
	end, { nargs = 1, complete = "file" })
end
