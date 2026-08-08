hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

-- Colors
local muted = 0xff6e6a86
local iris = 0xffc4a7e7
local mainMod = "SUPER"

local terminal = "kitty"
local scriptsDir = os.getenv("NIX_CFG_DIR") .. "/scripts/bin"
local qsDir = os.getenv("NIX_CFG_DIR") .. "/config/quickshell"
local brightness = scriptsDir .. "/brightness"
local volume = scriptsDir .. "/volume"
local ss = scriptsDir .. "/screenshot"
local ocr = scriptsDir .. "/ocr"
local lockcmd = scriptsDir .. "/lock"

hl.env("XCURSOR_SIZE", "20")
hl.env("HYPRCURSOR_THEME", "rose-pine-hyprcursor")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.animation({
	leaf = "windows",
	enabled = true,
	speed = 7,
	bezier = "myBezier",
})
hl.animation({
	leaf = "windowsOut",
	enabled = true,
	speed = 7,
	bezier = "default",
	style = "popin 80%",
})
hl.animation({
	leaf = "border",
	enabled = true,
	speed = 10,
	bezier = "default",
})
hl.animation({
	leaf = "borderangle",
	enabled = true,
	speed = 8,
	bezier = "default",
})
hl.animation({
	leaf = "fade",
	enabled = true,
	speed = 7,
	bezier = "default",
})
hl.animation({
	leaf = "workspaces",
	enabled = true,
	speed = 6,
	bezier = "default",
})

hl.layer_rule({
	name = "vicinae-blur",
	match = {
		namespace = "vicinae",
	},
	blur = true,
})

hl.layer_rule({
	name = "quickshell",
	match = {
		namespace = "quickshell",
	},
	blur = false,
})

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

hl.window_rule({
	match = {
		class = "pavucontrol",
	},
	float = true,
})

hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())

hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen())

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))

hl.bind(mainMod .. " + A", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + D", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + W", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + S", hl.dsp.focus({ direction = "down" }))

for i = 1, 9 do
	hl.bind("ALT + " .. i, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + " .. i, hl.dsp.window.move({ workspace = i }))
end

hl.bind("xf86MonBrightnessDown", hl.dsp.exec_cmd(brightness .. " --dec"), { repeating = true })
hl.bind("xf86MonBrightnessUp", hl.dsp.exec_cmd(brightness .. " --inc"), { repeating = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(volume .. " --inc"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(volume .. " --dec"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(volume .. " --mute"), { repeating = true })

hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("vicinae toggle"))

hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(ss .. " -n -c"))
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd(ocr .. " -o -c -n"))
hl.bind("SHIFT + ALT + S", hl.dsp.exec_cmd(ss .. " -n -d -c"))

hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd(lockcmd))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize())
hl.config({
	misc = {
		initial_workspace_tracking = 0,
		middle_click_paste = false,
		disable_hyprland_logo = true,
		vrr = 2,
		enable_swallow = false,
		swallow_regex = "^(kitty)$",
	},
	xwayland = {
		enabled = true,
	},
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",
		repeat_rate = 50,
		repeat_delay = 300,
		follow_mouse = 1,
		touchpad = {
			natural_scroll = true,
			disable_while_typing = false,
			middle_button_emulation = true,
			tap_to_click = true,
			drag_lock = false,
		},
		sensitivity = 0, -- -1.0 - 1.0, 0 means false modification.
	},
	general = {
		resize_on_border = true,
		gaps_in = 4,
		gaps_out = 8,
		border_size = 2,
		col = {
			active_border = iris,
			inactive_border = muted,
		},
		layout = "dwindle",
	},
	decoration = {
		rounding = 10,
		--blur = true
		--blur_size = 6
		--blur_passes = 1
		--blur_new_optimizations = on
		blur = {
			enabled = true,
			size = 6,
			passes = 1,
			new_optimizations = true,
		},
		--drop_shadow = false
		--shadow_range = 4
		--shadow_render_power = 3
		--col.shadow = rgba(1a1a1aee)
		shadow = {
			enabled = true,
			range = 4,
			render_power = 3,
			color = "rgba(1a1a1aee)",
		},
	},
	-- This crashes upon boot
	--render {
	--  new_render_scheduling = true
	--}
	animations = {
		enabled = true,
	},
	dwindle = {
		preserve_split = true,
		special_scale_factor = 0.8,
	},
	master = {
		--new_is_master = true
		new_status = "master",
	},
	--layerrule {
	--    name = vicinae-no-animation
	--    no_anim = on
	--    match:namespace = vicinae
	--}
	-- Make some windows float
})

hl.on("hyprland.start", function()
	hl.exec_cmd("wbg -s " .. os.getenv("WALLPAPER_DIR") .. "/hole.png")
	hl.exec_cmd("vicinae server")
	hl.exec_cmd("qs -c " .. qsDir)
	hl.exec_cmd(volume .. " --set 0")
	hl.exec_cmd("sh -c 'sleep 2 && kill -9 $(pgrep .kdeconnectd-wr)'")
end)
