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
			pcall(vim.system, { "yacht", "copy", "--source", "nvim" }, { stdin = text })
		end
	end

	local function paste()
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

	vim.api.nvim_create_user_command("YachtSave", function(o)
		local r = vim.system({ "yacht", "paste", "-o", o.args }):wait()
		if r.code ~= 0 then
			vim.notify(vim.trim(r.stderr or "yacht paste failed"), vim.log.levels.ERROR)
		end
	end, { nargs = 1, complete = "file" })
end
