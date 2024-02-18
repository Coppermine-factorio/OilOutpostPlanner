local layout = require("layout")

local function OnPlayerSelectedArea(event)
  --game.get_player(event.player_index).print("OnPlayerSelectedArea " .. event.item)
  if event.item ~= "oil-outpost-planner"
  then return end

  local player = event.player_index ~= nil and game.get_player(event.player_index) or nil
  if not player
  or not player.valid
  then return end

  layout.Plan(player, event.entities)
end

script.on_event(defines.events.on_player_selected_area, OnPlayerSelectedArea)
