local function FindPipePaths(args)
  local min_x = args.min_x
  local min_y = args.min_y
  local max_x = args.max_x
  local max_y = args.max_y
  local targets = args.targets
  local forbidden = args.forbidden

  -- Sanity check args
  assert(min_x < max_x, "Invalid x range")
  assert(min_y < max_y, "Invalid y range")
  assert(#targets, "Must have at least one target")

  -- Special case for a single target
  if #targets == 1
  then
    pipe = targets[1][1]
    return { directions = {defines.direction.north}, pipes = {pipe} }
  end

  -- We spread out from each target in parallel until two collide, then join
  -- those two along the shortest path.  As soon as we join two, they become
  -- one combined target which we reset and spread out from once more.
  -- Once all targets have combined into one large set, we are done.
  error("Unimplemented")
end

local function OnPlayerSelectedArea(event)
  game.get_player(event.player_index).print("OnPlayerSelectedArea " .. event.item)
  if event.item ~= "Oil Outpost Generator"
  then return end

  local player = event.player_index ~= nil and game.get_player(event.player_index) or nil
  if not player
  or not player.valid
  then return end

  local oil_patches = {}

  for _, entity in ipairs(event.entities)
  do
    if entity.valid
    and entity.type == "resource"
    then
      if (entity.name == "crude-oil")
      then
        player.print("Found oil!")
        table.insert(oil_patches, entity)
      end
    end
  end

  if #oil_patches == 0
  then
    player.print("No oil patches found")
    return
  end

  local surface = player.surface
  local out_pipe_sets = {}
  local forbidden_points = {}
  local min_x = 1e10
  local min_y = min_x
  local max_x = -min_x
  local max_y = max_x

  for _, patch in pairs(oil_patches)
  do
    local pos = patch.position
    table.insert(
      out_pipe_sets,
      {
        { x = pos.x + 1, y = pos.y - 2 },
        { x = pos.x + 2, y = pos.y - 1 },
        { x = pos.x - 1, y = pos.y + 2 },
        { x = pos.x - 2, y = pos.y + 1 },
      }
    )
    for off_x=-1,1
    do
      for off_y=-1,1
      do
        forbidden_points[{ x = pos.x + off_x, y = pos.y + off_y}] = true
      end
    end

    min_x = math.min(min_x, pos.x - 1)
    min_y = math.min(min_y, pos.y - 1)
    max_x = math.max(max_x, pos.x + 1)
    max_y = math.max(max_y, pos.y + 1)
  end

  result = FindPipePaths{
    min_x=min_x,
    min_y=min_y,
    max_x=max_x,
    max_y=max_y,
    targets=out_pipe_sets,
    forbidden=forbidden_points
  }

  if result == nil
  then
    player.print("Search for pipe layout failed")
    return
  end

  local directions = result.directions
  local pipes = result.pipes

  assert(#oil_patches == #directions, "Did not get one direction per patch")

  for i, patch in pairs(oil_patches)
  do
    local position = patch.position
    local direction = directions[i]
    surface.create_entity{
      name="entity-ghost",
      inner_name="pumpjack",
      position=position,
      direction=direction,
      force=player.force,
      player=player,
    }
  end

  for _, pipe_pos in pairs(pipes)
  do
    surface.create_entity{
      name="entity-ghost",
      inner_name="pipe",
      position=pipe_pos,
      force=player.force,
      player=player,
    }
    --player.print("position = " .. serpent.block(position))
  end
end

local function OnPlayerDroppedItem(event)
  local entity = event.entity
  if entity
  and entity.valid
  and entity.stack
  and entity.stack.name == "Oil Outpost Generator"
  then
    entity.stack.clear()
  end
end

script.on_event(defines.events.on_player_selected_area, OnPlayerSelectedArea)
script.on_event(defines.events.on_player_dropped_item, OnPlayerDroppedItem)
