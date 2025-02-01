local common = require("common")
local gui = require("gui")
local layout = require("layout")

local function get_player_config(player)
  player_index = player.index
  if storage.players == nil
  then
    storage.players = {}
  end
  if storage.players[player_index] == nil
  then
    local default_choices = {
      ["basic-fluid_pumpjack_choice"] = "pumpjack",
    }
    for _, selection in pairs(common.simple_entity_selections)
    do
      default_choices[selection.name.."_choice"] = selection.default
    end

    storage.players[player_index] = {
      choices = default_choices,

      gui = {
        section = {},
        tables = {},
        quality_selections = {},
        selections = {},
      },

      qualities = {},
    }
  end
  return storage.players[player_index]
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

local function reset_gui(player)
  local frame = player.gui.screen["oop_settings_frame"]
  if frame
  then
    frame.destroy()
  end
end

local function reset_all_guis()
  for _, player in pairs(game.players)
  do
    reset_gui(player)
  end
end

script.on_configuration_changed(function(config_changed_data)
  -- Reset all our global state to defaults
  game.print({"oil-outpost-planner.msg_config_change"})
  storage.players = nil

  reset_all_guis()
end)

script.on_event(defines.events.on_runtime_mod_setting_changed,
function(setting_changed_data)
  local player_index = setting_changed_data.player_index
  local is_global = setting_changed_data.setting_type == "runtime-global"
  if player_index == nil or is_global
  then
    reset_all_guis()
  else
    player = game.players[player_index]
    reset_gui(player)
  end
end)
