-- Recipe: add to your neovim config (nixvim: `extraConfigLua`).
--
-- Bare TTY only (no WAYLAND_DISPLAY/DISPLAY), so neovim finds no wl-copy/xclip.
--   copy : OSC 52, so the terminal sets its own clipboard too.
--   paste: `yacht paste` (newest history entry). Neovim's OSC 52 *paste* needs a
--          terminal query round trip and times out on many terminals, so we avoid it.
-- Needs neovim >= 0.10 for vim.ui.clipboard.osc52.
if vim.env.WAYLAND_DISPLAY == nil and vim.env.DISPLAY == nil then
  local osc52 = require("vim.ui.clipboard.osc52")
  vim.g.clipboard = {
    name = "osc52+yacht",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = { "yacht", "paste" }, ["*"] = { "yacht", "paste" } },
  }
end
