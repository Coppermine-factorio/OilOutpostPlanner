local gui = require("gui")
local layout = require("layout")

local function get_player_config(player)
  player_index = player.index
  if global.players == nil
  then
    global.players = {}
  end
  if global.players[player_index] == nil
  then
    global.players[player_index] = {
      choices = {
        pole_choice = "medium-electric-pole",
      },

      gui = {
        section = {},
        tables = {},
        selections = {},
      },
    }
  end
  return global.players[player_index]
end

local function OnPlayerSelectedArea(event)
  --game.get_player(event.player_index).print("OnPlayerSelectedArea " .. event.item)
  if event.item ~= "oil-outpost-planner"
  then return end

  local player = event.player_index ~= nil and game.get_player(event.player_index) or nil
  if not player
  or not player.valid
  then return end

  local player_data = get_player_config(player)
  if not player_data then return end

  layout.Plan(player, player_data, event.entities)
end

script.on_event(defines.events.on_player_selected_area, OnPlayerSelectedArea)

script.on_event(defines.events.on_gui_click, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  local player_data = get_player_config(player)
  if not player_data then return end

  gui.on_click(event, player, player_data)
end
)

local function cursor_stack_check(e)
  local player = game.get_player(e.player_index)
  if not player then return end
  local player_data = get_player_config(player)
  if not player_data then return end

  local cursor_stack = player.cursor_stack
  if (cursor_stack and
    cursor_stack.valid and
    cursor_stack.valid_for_read and
    cursor_stack.name == "oil-outpost-planner"
  ) then
    gui.show_interface(player, player_data)
  else
    gui.hide_interface(player, player_data)
  end
end

script.on_event(
  defines.events.on_player_cursor_stack_changed, cursor_stack_check)

script.on_event(defines.events.on_player_changed_surface, cursor_stack_check)
