local layout = {}

local orthogonal_neighbours = {
  { x = -1, y = 0 },
  { x = 0, y = 1 },
  { x = 1, y = 0 },
  { x = 0, y = -1 },
}

local function round(x)
  return math.floor(x+0.5)
end

local function IsEmpty(t)
  -- Returns the first value from a table
  for _, _ in pairs(t)
  do
    return false
  end

  return true
end

local function First(t)
  -- Returns the first value from a table
  for _, v in pairs(t)
  do
    return v
  end

  return nil
end

local function MoreThanOne(t)
  -- Returns true if the given table has more than one value
  local count = 0
  for _, _ in pairs(t)
  do
    count = count + 1
    if count > 1
    then
      return true
    end
  end
  return false
end

local function Pos2Str(pos)
  return pos.x..","..pos.y
end

local function Str2Pos(str)
  local a, b = str:find(",")
  assert(a, "Invalid string")
  x = tonumber(str:sub(1, a-1))
  y = tonumber(str:sub(b+1))
  return { x = x, y = y }
end

local function ForceGhostAt(args)
  local surface = args.surface
  local name = args.name
  local position = args.position
  local direction = args.direction
  local player = args.player

  new_entity = surface.create_entity{
    name="entity-ghost",
    inner_name=name,
    position=position,
    direction=direction,
    raise_built=true,
    force=player.force,
    player=player,
  }

  existing = surface.find_entities_filtered{
    area=new_entity.bounding_box,
    collision_mask={"object", "rail", "transport_belt"}
  }
  for _, entity in pairs(existing)
  do
    if entity ~= new_entity
    then
      entity.order_deconstruction(player.force, player)
    end
  end

  return new_entity
end

local function Collides(proto1, proto2)
  local layers1 = proto1.collision_mask.layers
  local layers2 = proto2.collision_mask.layers

  for name, _ in pairs(layers1)
  do
    if layers2[name]
    then
      return true
    end
  end

  return false
end

local function AddLandfillUnder(args)
  local player = args.player
  local ghosts = args.ghosts

  for _, ghost in pairs(ghosts)
  do
    local surface = ghost.surface
    local entity_proto = ghost.ghost_prototype
    local tiles = surface.find_tiles_filtered{
      area=ghost.bounding_box,
      collision_mask=entity_proto.collision_mask.layers
    }

    for _, tile in pairs(tiles)
    do
      if tile.name == "out-of-map"
      then
        goto skip
      end

      local tile_proto = tile.prototype

      while true
      do
        local cover_tile = tile_proto.default_cover_tile

        if not Collides(tile_proto, entity_proto)
        then
          break
        end

        if cover_tile == nil
        then
          -- Hardcode concrete as the cover for meltable tiles for Aquilo; I
          -- don't know how we're supposed to know that this is the 'correct'
          -- tile for this surface.
          cover_tile = prototypes.tile["concrete"]
        end

        surface.create_entity{
          name="tile-ghost",
          position=tile.position,
          inner_name=cover_tile.name,
          raise_built=true,
          player=player,
          force=player.force
        }

        tile_proto = cover_tile
      end

      ::skip::
    end
  end
end

local function AddForbiddenPoints(args)
  local min_x = args.bounds.min_x
  local min_y = args.bounds.min_y
  local max_x = args.bounds.max_x
  local max_y = args.bounds.max_y
  local surface = args.surface
  local force = args.force
  local forbidden = args.forbidden

  for x = min_x,max_x
  do
    for y = min_y,max_y
    do
      pos = {x = x, y = y}
      if not surface.can_place_entity{
        name="pipe",
        position=pos,
        force=force,
        build_check_type=defines.build_check_type.blueprint_ghost,
        forced=true,
      }
      then
        forbidden[Pos2Str(pos)] = true
      end
    end
  end
end

local function SolveSteinerTree(args)
  local min_x = args.bounds.min_x
  local min_y = args.bounds.min_y
  local max_x = args.bounds.max_x
  local max_y = args.bounds.max_y
  local targets = args.targets
  local adjacency = args.adjacency
  local forbidden = args.forbidden
  local choose_subtarget = args.choose_subtarget
  local debug_viz_surface = args.debug_viz_surface

  -- Sanity check args
  assert(min_x < max_x, "Invalid x range")
  assert(min_y < max_y, "Invalid y range")
  assert(#targets, "Must have at least one target")

  -- Remove forbidden points from the targets
  for _, target in pairs(targets)
  do
    for i, subtarget in pairs(target)
    do
      if forbidden[Pos2Str(subtarget)]
      then
        target[i] = nil
      end
    end

    if IsEmpty(target)
    then
      args.debug({"oil-outpost-planner.msg_all_subtargets_invalid"})
      return nil
    end
  end

  -- Special case for a single target
  if #targets == 1
  then
    path_node = First(targets[1])
    choose_subtarget(1, 1, path_node)
    return {
      paths = { [Pos2Str(path_node)] = path_node },
    }
  end

  -- We spread out from each target in parallel until two collide, then join
  -- those two along the shortest path.  As soon as we join two, they become
  -- one combined target which we reset and spread out from once more.
  -- Once all targets have combined into one large set, we are done.

  -- For each i:
  --   target_neighbourhoods[i] is an array of points in that neighbourhood,
  --     sorted in increasing order of disance from the target
  --   target_neighbourhood_index[i] is an index into target_neighbourhoods[i]
  --     of the next entry to examine
  local nearest_target_to = {}
  local target_neighbourhoods = {}
  local target_neighbourhood_index = {}

  local paths = {}

  local function ClearNeighbourhood(target_idx)
    for _, n in pairs(target_neighbourhoods[target_idx])
    do
      nearest_target_to[Pos2Str(n.pos)] = nil
    end
    target_neighbourhoods[target_idx] = nil
    target_neighbourhood_index[target_idx] = nil
  end

  for target_idx, target_set in pairs(targets)
  do
    target_neighbourhoods[target_idx] = {}
    target_neighbourhood_index[target_idx] = 1

    for subtarget_idx, subtarget in pairs(target_set)
    do
      subtarget_str = Pos2Str(subtarget)
      if not forbidden[subtarget_str]
      then
        if nearest_target_to[subtarget_str] ~= nil
        then
          -- Two targets share a square where a path could start.
          -- Immediately pick the subtarget for both and merge their
          -- target_neighbournoods accordinly
          choose_subtarget(target_idx, subtarget_idx, subtarget)
          ClearNeighbourhood(target_idx)

          other_target_info = nearest_target_to[subtarget_str]
          other_target = other_target_info.target
          other_subtarget_idx = other_target_info.subtarget_idx
          if other_subtarget_idx ~= nil
          then
            choose_subtarget(other_target, other_subtarget_idx, subtarget)
            ClearNeighbourhood(other_target)
            nearest_target_to[subtarget_str] = {target=other_target}
            target_neighbourhoods[other_target] = {}
            target_neighbourhood_index[other_target] = 1
            table.insert(
              target_neighbourhoods[other_target],
              {pos=subtarget, distance=1}
            )
            paths[subtarget_str] = subtarget
            if debug_viz_surface ~= nil
            then
              rendering.draw_text{
                text="x",
                surface=debug_viz_surface,
                target=subtarget,
                color={1,1,1}
              }
            end
          end
          break
        else
          nearest_target_to[subtarget_str] = {
            target=target_idx, subtarget_idx=subtarget_idx
          }
          table.insert(
            target_neighbourhoods[target_idx],
            {pos=subtarget, distance=1}
          )
        end
      end
    end
  end

  --print(serpent.block({ min_x=min_x, max_x=max_x, min_y=min_y, max_y=max_y}))
  --print("forbidden = "..serpent.block(forbidden))

  local function FindMergeTarget()
    local process_distance = 1
    while true
    do
      for i, target_neighbourhood in pairs(target_neighbourhoods)
      do
        local idx = target_neighbourhood_index[i]
        assert(idx ~= nil, "idx == nil")

        while true
        do
          local next_neighbour = target_neighbourhood[idx]

          if next_neighbour == nil
          then
            --print("next_neighbour was nil")
            --print("idx = "..idx)
            --print("#target_neighbourhood = "..#target_neighbourhood)
            return nil
          end

          --print("next_neighbour = "..serpent.line(next_neighbour))
          assert(next_neighbour.distance >= process_distance,
            "Values out of order")

          if next_neighbour.distance > process_distance
          then
            break
          end

          local pos = next_neighbour.pos
          --print("idx = "..idx..", pos ("..pos.x..","..pos.y..")")

          for _, off in pairs(adjacency)
          do
            local candidate = { x = pos.x + off.x, y = pos.y + off.y }
            local candidate_s = Pos2Str(candidate)
            local valid = (
              candidate.x >= min_x
              and candidate.x <= max_x
              and candidate.y >= min_y
              and candidate.y <= max_y
              and not forbidden[candidate_s])
            --print("Considering candidate ("..candidate.x..","..candidate.y.."), forbidden="..serpent.block(forbidden[candidate_s])..", valid="..serpent.block(valid))
            if valid
            then
              --print("Candidate valid position")
              local nearest_target_info = nearest_target_to[candidate_s]
              if nearest_target_info == nil
              then
                --print("Candidate is a new position")
                nearest_target_to[candidate_s] = { target=i, next_pos=pos }
                --print("nearest_target_to = "..serpent.block(nearest_target_to))
                table.insert(target_neighbourhood, {pos=candidate, distance=process_distance+1})
              else
                local other_target = nearest_target_info.target
                if other_target == i
                then
                  --print("Candidate a self reference")
                else
                  return {
                    t1 = i,
                    t2 = other_target,
                    pos1 = pos,
                    pos2 = candidate
                  }
                end
              end
            end
          end

          idx = idx + 1

          if idx > 10000
          then
            args.debug({"oil-outpost-planner.msg_too_big"})
            return nil
          end
        end

        target_neighbourhood_index[i] = idx
      end

      process_distance = process_distance + 1
    end
  end

  local path_index = 0

  while MoreThanOne(target_neighbourhoods)
  do
    local merge_target = FindMergeTarget()

    if merge_target == nil
    then
      return nil
    end
    --print("Got a merge target "..serpent.line(merge_target))

    -- We have found a pair of targets to be merged.  We construct the path
    -- connecting them and set the subtarget
    local pos1 = merge_target.pos1
    local pos2 = merge_target.pos2
    local this_path = {}
    local chosen_subtargets = {}

    for _, pos in pairs({pos1, pos2})
    do
      while true
      do
        assert(pos ~= nil, "Expected real pos")
        --print("Adding path node at "..serpent.line(pos))
        table.insert(this_path, pos)

        if #this_path > 500
        then
          args.debug("Generated path was too long")
          return nil
        end

        local n = nearest_target_to[Pos2Str(pos)]
        assert(n ~= nil, "Expected neighbour")
        local next_pos = n.next_pos
        if next_pos ~= nil
        then
          pos = next_pos
        else
          local subtarget_idx = n.subtarget_idx
          if subtarget_idx ~= nil
          then
            local target = n.target
            assert(target ~= nil, "Expected target")
            choose_subtarget(target, subtarget_idx, pos)
            chosen_subtargets[target] = subtarget_idx
          else
            --print("No subtarget_idx in "..serpent.line(n))
          end
          break
        end
      end
    end

    local t1 = merge_target.t1
    local t2 = merge_target.t2

    -- Gather old distance-1 neighbourhoods for each marged target (but only
    -- for the chosen subtarget, when applicable)
    local old_neighbouhoods = {}
    for _, t in pairs({t1, t2})
    do
      local t_neighbourhood = target_neighbourhoods[t]
      for _, neighbour in pairs(t_neighbourhood)
      do
        if neighbour.distance > 1
        then
          break
        end

        local pos = neighbour.pos
        local n = nearest_target_to[Pos2Str(pos)]
        local subtarget = n.subtarget_idx

        if subtarget == nil or subtarget == chosen_subtargets[t]
        then
          table.insert(old_neighbouhoods, { pos=neighbour.pos, distance=1 })
        end
      end
    end

    ClearNeighbourhood(t1)
    ClearNeighbourhood(t2)

    -- Initialize the new neighbourhood as the union of the two old distance-1
    -- neighbourhoods and the path between them
    target_neighbourhoods[t1] = old_neighbouhoods
    target_neighbourhood_index[t1] = 1
    local t1_neighbourhood = target_neighbourhoods[t1]

    for _, neighbour in pairs(t1_neighbourhood)
    do
      pos_str = Pos2Str(neighbour.pos)
      nearest_target_to[pos_str] = { target=t1 }
    end

    for _, path_node in pairs(this_path)
    do
      table.insert(t1_neighbourhood, { pos=path_node, distance=1 })
      path_node_str = Pos2Str(path_node)
      nearest_target_to[path_node_str] = { target=t1 }
      paths[path_node_str] = path_node

      if debug_viz_surface ~= nil
      then
        rendering.draw_text{
          text=tostring(path_index),
          surface=debug_viz_surface,
          target=path_node,
          color={1,1,1}
        }
      end
    end

    path_index = path_index + 1
  end

  return {
    paths=paths
  }
end

local function FindPipePaths(args)
  local bounds = args.bounds
  local targets = args.targets
  local forbidden = args.forbidden
  local min_underground_distance = args.min_underground_distance
  local max_underground_distance = args.max_underground_distance
  local debug_viz_surface = args.debug_viz_surface

  local directions = {}
  local directional_pipes = {}

  local function ChooseSubtarget(target_idx, subtarget_idx, pos)
    --print("ChooseSubtarget("..target_idx..", "..subtarget_idx..", "..serpent.line(pos)..")")
    directions[target_idx] = subtarget_idx
    pos_str = Pos2Str(pos)
    if directional_pipes[pos_str] == nil
    then
      directional_pipes[pos_str] = subtarget_idx
    else
      directional_pipes[pos_str] = 0
    end
  end

  local tree_result = SolveSteinerTree{
    targets=targets,
    adjacency=orthogonal_neighbours,
    bounds=bounds,
    forbidden=forbidden,
    choose_subtarget=ChooseSubtarget,
    debug=args.debug,
    debug_viz_surface=debug_viz_surface
  }

  if tree_result == nil
  then
    return nil
  end

  local pipes = tree_result.paths
  local undergrounds = {}

  -- Now we have placed all the pipes, we want to search for places where we
  -- might be able to replace a sequence of pipes with an underground pipe.
  local function ReplacePipes(args)
    local outer_name = args.outer
    local min_outer = args.min_outer
    local max_outer = args.max_outer
    local inner_name = args.inner
    local min_inner = args.min_inner
    local max_inner = args.max_inner
    local lower_direction = args.lower_direction
    local upper_direction = args.upper_direction
    local valid_directions = args.valid_directions

    for outer = min_outer, max_outer
    do
      local start_of_run = nil

      for inner = min_inner, max_inner+1
      do
        local pos = { [outer_name] = outer, [inner_name] = inner }
        local existing_direction = directional_pipes[Pos2Str(pos)]
        local has_pipe = (
          pipes[Pos2Str(pos)] ~= nil and
          (existing_direction == nil or valid_directions[existing_direction]))
        if has_pipe
        then
          for _, offset in pairs({-1, 1})
          do
            offset_pos = { [outer_name] = outer, [inner_name] = inner }
            offset_pos[outer_name] = offset_pos[outer_name] + offset
            offset_pos_str = Pos2Str(offset_pos)
            if (pipes[offset_pos_str] ~= nil or
              undergrounds[offset_pos_str] ~= nil)
            then
              has_pipe = false
              break
            end
          end
        end

        -- At this point has_pipe tells us whether we have a pipe with no
        -- problem neighbours
        --print("pipe conversion - has_pipe="..serpent.line(has_pipe)..", "..outer_name.."="..outer..", "..inner_name.."="..inner..", existing_direction="..serpent.line(existing_direction))
        if has_pipe and start_of_run == nil
        then
          start_of_run = inner
        end

        if not has_pipe and start_of_run ~= nil
        then
          length_of_run = inner - start_of_run
          assert(length_of_run ~= nil, "Bad length")
          assert(min_underground_distance ~= nil, "Bad min_underground_distance")
          --print("Doing pipe conversion of length "..length_of_run)
          if length_of_run >= min_underground_distance
          then
            -- We have a range which we can change into an underground (or
            -- sequence of undergrounds)!
            for run_inner = start_of_run, inner - 1
            do
              pipes[Pos2Str({[outer_name]=outer, [inner_name]=run_inner})] = nil
            end

            num_sections_needed = math.ceil(
              (length_of_run+1)/(max_underground_distance+1)
            )
            for i = 0, num_sections_needed-1
            do
              section_start = start_of_run + round(
                length_of_run*i/num_sections_needed)
              section_end = start_of_run + round(
                length_of_run*(i+1)/num_sections_needed) - 1
              start_pos = { [outer_name]=outer, [inner_name]=section_start }
              end_pos = { [outer_name]=outer, [inner_name]=section_end }
              undergrounds[Pos2Str(start_pos)] = {
                pos=start_pos, direction=lower_direction
              }
              undergrounds[Pos2Str(end_pos)] = {
                pos=end_pos, direction=upper_direction
              }
            end
          end
          start_of_run = nil
        end
      end
    end
  end

  local valid_directions = {}
  valid_directions[1] = true
  valid_directions[3] = true
  ReplacePipes{
    outer="x",
    min_outer=bounds.min_x,
    max_outer=bounds.max_x,
    inner="y",
    min_inner=bounds.min_y,
    max_inner=bounds.max_y,
    valid_directions=valid_directions,
    lower_direction=defines.direction.north,
    upper_direction=defines.direction.south,
  }
  local valid_directions = {}
  valid_directions[2] = true
  valid_directions[4] = true
  ReplacePipes{
    outer="y",
    min_outer=bounds.min_y,
    max_outer=bounds.max_y,
    inner="x",
    min_inner=bounds.min_x,
    max_inner=bounds.max_x,
    valid_directions=valid_directions,
    lower_direction=defines.direction.west,
    upper_direction=defines.direction.east,
  }

  return {
    directions = directions,
    pipes = pipes,
    undergrounds = undergrounds,
  }
end

local function FindHeatPipePaths(args)
  local bounds = args.bounds
  local entities = args.entities
  local forbidden = args.forbidden

  local targets = {}

  for _, entity in pairs(entities)
  do
    local entity_pos = entity.position
    local entity_proto = entity.ghost_prototype
    local entity_radius = entity_proto.selection_box.right_bottom.x
    local heat_pipe_range = entity_radius + 0.5
    --local pumpjack_radius_int = math.floor(pumpjack_radius)

    local subtargets = {}
    for x = -heat_pipe_range,heat_pipe_range
    do
      local pos = { x = entity_pos.x + x, y = entity_pos.y + heat_pipe_range }
      table.insert(subtargets, pos)
      local pos2 = { x = entity_pos.x + x, y = entity_pos.y - heat_pipe_range }
      table.insert(subtargets, pos2)
    end
    for y = 1-heat_pipe_range,heat_pipe_range-1
    do
      local pos = { x = entity_pos.x + heat_pipe_range, y = entity_pos.y + y }
      table.insert(subtargets, pos)
      local pos2 = { x = entity_pos.x - heat_pipe_range, y = entity_pos.y + y }
      table.insert(subtargets, pos2)
    end
    table.insert(targets, subtargets)
  end

  local function ChooseSubtarget(target_idx, subtarget_idx, pos)
    -- no implementation needed
  end

  local tree_result = SolveSteinerTree{
    targets=targets,
    adjacency=orthogonal_neighbours,
    bounds=bounds,
    forbidden=forbidden,
    choose_subtarget=ChooseSubtarget,
    debug=args.debug,
  }

  if tree_result == nil
  then
    return nil
  end

  return {
    heat_pipe_poss = tree_result.paths
  }
end

local function FindPowerPolePositions(args)
  local bounds = args.bounds
  local entities = args.entities
  local forbidden = args.forbidden
  local entity_to_pole_max = args.entity_to_pole_max
  local wire_reach = args.wire_reach

  local subtarget_offsets = {}
  for x = -entity_to_pole_max,entity_to_pole_max
  do
    for y = -entity_to_pole_max,entity_to_pole_max
    do
      local pos = { x = x, y = y }
      table.insert(subtarget_offsets, pos)
    end
  end
  table.sort(subtarget_offsets, function(l, r)
    return l.x * l.x + l.y * l.y < r.x * r.x + r.y * r.y
  end)

  local targets = {}

  for _, entity in pairs(entities)
  do
    local subtargets = {}
    for _, offset in pairs(subtarget_offsets)
    do
      local pos = { x = entity.x + offset.x, y = entity.y + offset.y }
      table.insert(subtargets, pos)
    end
    table.insert(targets, subtargets)
  end

  local squared_wire_reach = wire_reach * wire_reach
  local wire_reach_int = math.floor(wire_reach)
  local pole_adjacency = {}

  for x = -wire_reach_int,wire_reach_int
  do
    for y = -wire_reach_int,wire_reach_int
    do
      local square_distance = x * x + y * y
      if square_distance <= squared_wire_reach
      then
        local pos = { x = x, y = y }
        table.insert(pole_adjacency, pos)
      end
    end
  end

  local function ChooseSubtarget(target_idx, subtarget_idx, pos)
    -- Nothing to do
  end

  tree_result = SolveSteinerTree{
    targets=targets,
    adjacency=pole_adjacency,
    bounds=bounds,
    forbidden=forbidden,
    choose_subtarget=ChooseSubtarget,
    debug=args.debug,
  }

  if tree_result == nil
  then
    return nil
  end

  local poles = tree_result.paths

  return {
    pole_poss = poles
  }
end

function layout.Plan(player, player_data, entities)
  local oil_patches = {}
  local chosen_entity_name
  local resource_category
  local choice_key

  for _, entity in ipairs(entities)
  do
    local entity_proto = entity.prototype

    if chosen_entity_name == nil
    then
      if entity.valid
      and entity.type == "resource"
      then
        resource_category = entity_proto.resource_category
        choice_key = resource_category.."_pumpjack_choice"
        if player_data.choices[choice_key]
        then
          --player.print("Found oil!")
          table.insert(oil_patches, entity)
          chosen_entity_name = entity.name
        end
      end
    else
      if entity.name == chosen_entity_name
      then
        table.insert(oil_patches, entity)
      end
    end
  end

  if #oil_patches == 0
  then
    player.print({"oil-outpost-planner.msg_no_patches"})
    return
  end

  assert(resource_category ~= nil, "Failed to get category")
  assert(choice_key ~= nil, "Failed to get choice key")

  player.print({
    "oil-outpost-planner.msg_count_patches",
    {"entity-name."..chosen_entity_name},
    #oil_patches
  })

  local direction_array = {
    defines.direction.north,
    defines.direction.east,
    defines.direction.south,
    defines.direction.west,
  }

  -- Offsets corresponding to the respective directions in direction_array
  local direction_offset_array = {
    { x = 0, y = -1 },
    { x = 1, y = 0 },
    { x = 0, y = 1 },
    { x = -1, y = 0 },
  }

  local surface = player.surface
  local planet = surface.planet
  local entities_require_heating = false
  if planet ~= nil
  then
    entities_require_heating = planet.prototype.entities_require_heating
  end

  local pipe_type = player_data.choices["pipe_choice"]
  local underground_pipe_type = player_data.choices["pipe-to-ground_choice"]
  local pumpjack_type = player_data.choices[choice_key]
  local heat_pipe_type = "heat-pipe"

  local underground_proto
  local min_underground_distance
  local max_underground_distance
  if underground_pipe_type == "none"
  then
    min_underground_distance = 1e10
  else
    underground_proto = prototypes.entity[underground_pipe_type]
    max_underground_distance = underground_proto.max_underground_distance
    min_underground_distance = 3
  end

  local pumpjack_proto = prototypes.entity[pumpjack_type]
  local pumpjack_radius = pumpjack_proto.selection_box.right_bottom.x
  local pumpjack_radius_int = math.floor(pumpjack_radius)
  local padding = pumpjack_radius_int + 2

  local output_fluidboxes = {}
  for _, fluidbox in pairs(pumpjack_proto.fluidbox_prototypes)
  do
    if fluidbox.production_type == "output"
    then
      table.insert(output_fluidboxes, fluidbox)
    end
  end

  if #output_fluidboxes == 0
  then
    player.print({"oil-outpost-planner.msg_no_fluidbox"})
    return
  end

  if #output_fluidboxes > 1
  then
    player.print({"oil-outpost-planner.msg_multiple_fluidboxes"})
    return
  end
  local output_fluidbox = output_fluidboxes[1]

  if #output_fluidbox.pipe_connections == 0
  then
    player.print({"oil-outpost-planner.msg_no_fluidbox"})
    return
  end

  if #output_fluidbox.pipe_connections > 1
  then
    player.print({"oil-outpost-planner.msg_multiple_fluidboxes"})
    return
  end
  local pipe_connection = output_fluidbox.pipe_connections[1]

  local out_pipe_sets = {}
  local forbidden_points = {}
  local min_x = 1e10
  local min_y = min_x
  local max_x = -min_x
  local max_y = max_x

  for _, patch in pairs(oil_patches)
  do
    local pos = patch.position
    local subtargets = {}
    for i, offset in pairs(pipe_connection.positions)
    do
      direction_offset = direction_offset_array[i]
      table.insert(
        subtargets,
        {
          x = pos.x + offset.x + direction_offset.x,
          y = pos.y + offset.y + direction_offset.y,
        }
      )
    end
    table.insert(out_pipe_sets, subtargets)

    for off_x=-pumpjack_radius_int,pumpjack_radius_int
    do
      for off_y=-pumpjack_radius_int,pumpjack_radius_int
      do
        local offset_pos = { x = pos.x + off_x, y = pos.y + off_y}
        forbidden_points[Pos2Str(offset_pos)] = true
      end
    end

    min_x = math.min(min_x, pos.x - padding)
    min_y = math.min(min_y, pos.y - padding)
    max_x = math.max(max_x, pos.x + padding)
    max_y = math.max(max_y, pos.y + padding)
  end

  local bounds = {
    min_x=min_x,
    min_y=min_y,
    max_x=max_x,
    max_y=max_y,
  }

  AddForbiddenPoints{
    forbidden=forbidden_points,
    force=player.force,
    surface=surface,
    bounds=bounds,
  }

  local result = FindPipePaths{
    bounds=bounds,
    targets=out_pipe_sets,
    forbidden=forbidden_points,
    min_underground_distance=min_underground_distance,
    max_underground_distance=max_underground_distance,
    debug=player.print,
    --debug_viz_surface=surface
  }

  if result == nil
  then
    player.print({"oil-outpost-planner.msg_pipe_layout_failed"})
    return
  end

  local directions = result.directions
  local pipes = result.pipes
  local undergrounds = result.undergrounds

  --print("Got directions "..serpent.line(directions))
  assert(#oil_patches == #directions, "Did not get one direction per patch\n"
  ..serpent.line(oil_patches).."\n"..serpent.line(directions))

  pumpjack_positions = {}
  ghosts = {}

  for i, patch in pairs(oil_patches)
  do
    local position = patch.position
    table.insert(pumpjack_positions, position)
    local dir_index = directions[i]
    local direction = direction_array[dir_index]
    --print("Using direction "..direction.." for patch at "..serpent.line(position))
    local ghost = ForceGhostAt{
      surface=surface,
      name=pumpjack_type,
      position=position,
      direction=direction,
      player=player,
    }
    table.insert(ghosts, ghost)
  end

  for _, pipe_pos in pairs(pipes)
  do
    local ghost = ForceGhostAt{
      surface=surface,
      name=pipe_type,
      position=pipe_pos,
      player=player,
    }
    forbidden_points[Pos2Str(pipe_pos)] = true
    table.insert(ghosts, ghost)
  end

  for _, underground_info in pairs(undergrounds)
  do
    local pos = underground_info.pos
    local direction = underground_info.direction

    local ghost = ForceGhostAt{
      surface=surface,
      name=underground_pipe_type,
      position=pos,
      direction=direction,
      player=player,
    }
    forbidden_points[Pos2Str(pos)] = true
    table.insert(ghosts, ghost)
  end

  -- Next step is to add heat pipes, but only if the surface requires them
  if entities_require_heating
  then
    local result = FindHeatPipePaths{
      bounds=bounds,
      entities=ghosts,
      forbidden=forbidden_points,
      debug=player.print
    }

    if result == nil
    then
      player.print({"oil-outpost-planner.msg_heat_pipe_layout_failed"})
      return
    end

    local heat_pipe_poss = result.heat_pipe_poss
    for _, pos in pairs(heat_pipe_poss)
    do
      local ghost = ForceGhostAt{
        surface=surface,
        name=heat_pipe_type,
        position=pos,
        player=player,
      }
      forbidden_points[Pos2Str(pos)] = true
      table.insert(ghosts, ghost)
    end
  end

  -- Now pumpjacks and pipes are complete, the final step is to add power poles
  local power_pole_type = player_data.choices.pole_choice

  if power_pole_type == "none"
  then
    return
  end

  local power_pole_proto = prototypes.entity[power_pole_type]
  -- TODO: if we want to suport quality power poles, we need to pass quality
  -- to get_max_wire_distance and get_supply_area_distance
  local wire_reach = power_pole_proto.get_max_wire_distance()
  local target_to_pole_max = (
    power_pole_proto.get_supply_area_distance() + pumpjack_radius - 1)

  result = FindPowerPolePositions{
    bounds=bounds,
    entities=pumpjack_positions,
    forbidden=forbidden_points,
    entity_to_pole_max=target_to_pole_max,
    wire_reach=wire_reach,
    debug=player.print
  }

  if result == nil
  then
    player.print({"oil-outpost-planner.msg_pole_layout_failed"})
    return
  end

  pole_poss = result.pole_poss

  for _, pole_pos in pairs(pole_poss)
  do
    local ghost = ForceGhostAt{
      surface=surface,
      name=power_pole_type,
      position=pole_pos,
      player=player,
    }
    table.insert(ghosts, ghost)
  end

  local setting = player.mod_settings["oil-outpost-planner-interface-with-module-inserter-ex"]
  if setting and setting.value and remote.interfaces["ModuleInserterEx"] then
    remote.call(
      "ModuleInserterEx",
      "apply_module_config_to_entities",
      player.index,
      ghosts
    )
  end

  AddLandfillUnder{
    player=player,
    ghosts=ghosts,
    debug=player.print
  }
end

return layout
