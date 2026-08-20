--- STEAMODDED HEADER
--- MOD_NAME: Brainstorm Reroll Button
--- MOD_ID: BrainstormRerollButton
--- MOD_AUTHOR: [Jdbye]
--- MOD_DESCRIPTION: Adds a button to trigger Brainstorm's auto reroll to the escape menu and game over screen.
----------------------------------------------
------------MOD CODE -------------------------

function G.FUNCS.brainstorm_reroll_button(arg_736_0)
    Brainstorm.AUTOREROLL.autoRerollActive = not Brainstorm.AUTOREROLL.autoRerollActive
    G.SETTINGS.paused = false
end

local createOptionsRef = create_UIBox_options
function create_UIBox_options()
  contents = createOptionsRef()

  if G.STATE ~= G.STATES.MENU then
    local brainstorm_reroll_button = UIBox_button({
      minw = 5,
      button = "brainstorm_reroll_button",
      label = {
        "Auto Reroll"
      },
      colour = HEX('00A000')
    })
    table.insert(contents.nodes[1].nodes[1].nodes[1].nodes, 2, brainstorm_reroll_button)
  end
  return contents
end

local createGameOverRef = create_UIBox_game_over
function create_UIBox_game_over()
  contents = createGameOverRef()

  if G.STATE ~= G.STATES.MENU then
    -- create the button
    local brainstorm_reroll_button = {
	    n=G.UIT.R, config={align = "cm", minw = 5, padding = 0.1, r = 0.1, hover = true, colour = HEX('00A000'), button = "brainstorm_reroll_button", shadow = true, focus_args = {nav = 'wide', snap_to = true}}, nodes={
            {n=G.UIT.R, config={align = "cm", padding = 0, no_fill = true, maxw = 4.8}, nodes={
              {n=G.UIT.T, config={text = "Auto Reroll", scale = 0.5, colour = G.C.UI.TEXT_LIGHT}}
            }}
        }
    }
	
	-- set snap_to = false on New Run button (unsuccessful attempt to fix inconsistent spacing)
	contents.nodes[1].nodes[2].nodes[1].nodes[1].nodes[1].nodes[2].nodes[1].nodes[2].nodes[1].config.focus_args.snap_to = false
	
	-- insert the button
    table.insert(contents.nodes[1].nodes[2].nodes[1].nodes[1].nodes[1].nodes[2].nodes[1].nodes[2].nodes, 1, brainstorm_reroll_button)
  end
  return contents
end


----------------------------------------------
------------MOD CODE END----------------------
