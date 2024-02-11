local neighbours = {
  { x = -1, y = 0 },
  { x = 0, y = 1 },
  { x = 1, y = 0 },
  { x = 0, y = -1 },
}

local function round(x)
  return math.floor(x+0.5)
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

local function AddForbiddenPoints(args)
  local min_x = args.min_x
  local min_y = args.min_y
  local max_x = args.max_x
  local max_y = args.max_y
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
        build_check_type=defines.blueprint_ghost
      }
      then
        forbidden[Pos2Str(pos)] = true
      end
    end
  end
end

local function FindPipePaths(args)
  local min_x = args.min_x
  local min_y = args.min_y
  local max_x = args.max_x
  local max_y = args.max_y
  local targets = args.targets
  local forbidden = args.forbidden
  local min_underground_distance = args.min_underground_distance
  local max_underground_distance = args.max_underground_distance

  -- Sanity check args
  assert(min_x < max_x, "Invalid x range")
  assert(min_y < max_y, "Invalid y range")
  assert(#targets, "Must have at least one target")

  -- Special case for a single target
  if #targets == 1
  then
    pipe = targets[1][1]
    return { directions = {1}, pipes = { [Pos2Str(pipe)] = pipe } }
  end

  -- We spread out from each target in parallel until two collide, then join
  -- those two along the shortest path.  As soon as we join two, they become
  -- one combined target which we reset and spread out from once more.
  -- Once all targets have combined into one large set, we are done.
  local nearest_target_to = {}
  local target_neighbourhoods = {}
  local target_neighbourhood_index = {}

  local directions = {}
  local pipes = {}
  local directional_pipes = {}
  local undergrounds = {}

  for i, target_set in pairs(targets)
  do
    target_neighbourhoods[i] = {}
    target_neighbourhood_index[i] = 1

    for j, target in pairs(target_set)
    do
      if forbidden[target] == nil
      then
        target_str = Pos2Str(target)
        if nearest_target_to[target_str] ~= nil
        then
          -- Two pumpjacks share a square where a pipe could be attached.
          -- Immediately pick the directions for both and merge their
          -- target_neighbournoods accordinly
          directions[i] = j
          target_neighbourhoods[i] = nil
          directional_pipes[target] = 0

          other_target_info = nearest_target_to[target_str]
          other_target = other_target_info.target
          other_dir = other_target_info.direction
          if other_dir ~= nil
          then
            directions[other_target] = other_dir
            for _, n in pairs(target_neighbourhoods[other_target])
            do
              nearest_target_to[Pos2Str(n.pos)] = nil
            end
            nearest_target_to[target_str] = {target=other_target}
            target_neighbourhoods[other_target] = {}
            table.insert(
              target_neighbourhoods[other_target],
              {pos=target, distance=1}
            )
            pipes[Pos2Str(target)] = target
          end
          print("Merging targets.  directions["..i.."]="..j..", directions["..other_target.."]="..directions[other_target])
          break
        else
          nearest_target_to[target_str] = {target=i, direction=j}
          table.insert(target_neighbourhoods[i], {pos=target, distance=1})
        end
      end
    end
  end

  print(serpent.block({ min_x=min_x, max_x=max_x, min_y=min_y, max_y=max_y}))
  print("forbidden = "..serpent.block(forbidden))

  while MoreThanOne(target_neighbourhoods)
  do
    local process_distance = 1
    merge_target = nil

    while merge_target == nil
    do
      for i, target_neighbourhood in pairs(target_neighbourhoods)
      do
        local idx = target_neighbourhood_index[i]
        local next_neighbour = target_neighbourhood[idx]
        assert(next_neighbour.distance >= process_distance,
          "Values out of order")

        while merge_target == nil
          and next_neighbour.distance == process_distance
        do
          local pos = next_neighbour.pos
          print("idx = "..idx..", pos ("..pos.x..","..pos.y..")")

          for _, off in pairs(neighbours)
          do
            local candidate = { x = pos.x + off.x, y = pos.y + off.y }
            local candidate_s = Pos2Str(candidate)
            local valid = (
              forbidden[candidate_s] == nil
              and candidate.x >= min_x
              and candidate.x <= max_x
              and candidate.y >= min_y
              and candidate.y <= max_y)
            print("Considering candidate ("..candidate.x..","..candidate.y.."), forbidden="..serpent.block(forbidden[candidate_s])..", valid="..serpent.block(valid))
            if valid
            then
              print("Candidate valid position")
              local nearest_target_info = nearest_target_to[candidate_s]
              if nearest_target_info == nil
              then
                print("Candidate is a new position")
                nearest_target_to[candidate_s] = { target=i, next_pos=pos }
                --print("nearest_target_to = "..serpent.block(nearest_target_to))
                table.insert(target_neighbourhood, {pos=candidate, distance=process_distance+1})
              else
                local other_target = nearest_target_info.target
                if other_target == i
                then
                  print("Candidate a self reference")
                else
                  print("Candidate a merge target")
                  merge_target = {
                    t1 = i,
                    t2 = other_target,
                    pos1 = pos,
                    pos2 = candidate
                  }
                  break
                end
              end
            end
          end

          idx = idx + 1

          if idx > 10000
          then
            print("idx got too big")
            return nil
          end

          next_neighbour = target_neighbourhood[idx]

          if next_neighbour == nil
          then
            print("next_neighbour was nil")
            print("idx = "..idx)
            print("#target_neighbourhood = "..#target_neighbourhood)
            return nil
          end
        end

        if merge_target ~= nil
        then
          break
        end
        target_neighbourhood_index[i] = idx
      end

      process_distance = process_distance + 1
    end

    -- We have found a pair of targets to be merged.  We construct the pipe
    -- connecting them and set the direction of the pumpjack if applicable
    local pos1 = merge_target.pos1
    local pos2 = merge_target.pos2
    local these_pipes = {}

    for _, pos in pairs({pos1, pos2})
    do
      while true
      do
        assert(pos ~= nil, "Expected real pos")
        print("Adding pipe at "..serpent.line(pos))
        table.insert(these_pipes, pos)

        if #these_pipes > 500
        then
          print("these_pipes too large")
          return nil
        end

        local n = nearest_target_to[Pos2Str(pos)]
        local next_pos = n.next_pos
        if next_pos ~= nil
        then
          pos = next_pos
        else
          local direction = n.direction
          if direction ~= nil
          then
            local target = n.target
            assert(target ~= nil, "Expected target")
            directions[target] = direction
            assert(directional_pipes[pos] == nil, "Two directions for pipe")
            directional_pipes[pos] = direction
          else
            print("No direction in "..serpent.line(n))
          end
          break
        end
      end
    end

    local t1 = merge_target.t1
    local t2 = merge_target.t2

    for _, t in pairs({t1, t2})
    do
      for _, n in pairs(target_neighbourhoods[t])
      do
        nearest_target_to[Pos2Str(n.pos)] = nil
      end
    end

    target_neighbourhoods[t1] = {}
    target_neighbourhood_index[t1] = 1
    target_neighbourhoods[t2] = nil
    target_neighbourhood_index[t2] = nil

    t1_neighbourhood = target_neighbourhoods[t1]

    for _, pipe in pairs(these_pipes)
    do
      table.insert(t1_neighbourhood, { pos=pipe, distance=1 })
      nearest_target_to[Pos2Str(pipe)] = { target=t1 }
      pipes[Pos2Str(pipe)] = pipe
    end
  end

  -- Now we have placed all the pipes, we want to search for places where we
  -- might be able to replace a sequence of pipes with an underground pipe.
  for x = min_x, max_x
  do
    local start_of_run = nil

    for y = min_y, max_y+1
    do
      local pos = { x = x, y = y }
      local has_pipe = pipes[Pos2Str(pos)] ~= nil
      if has_pipe
      then
        for _, offset_x in pairs({-1, 1})
        do
          offset_pos = { x = x + offset_x, y = y }
          if pipes[Pos2Str(offset_pos)] ~= nil
          then
            has_pipe = false
            break
          end
        end
      end

      -- At this point has_pipe tells us whether we have a pipe with no problem
      -- neighbours
      print("pipe conversion - has_pipe="..serpent.line(has_pipe)..", x="..x..", y="..y)
      if has_pipe and start_of_run == nil
      then
        start_of_run = y
      end

      if not has_pipe and start_of_run ~= nil
      then
        length_of_run = y - start_of_run
        assert(length_of_run ~= nil, "Bad length")
        assert(min_underground_distance ~= nil, "Bad min_underground_distance")
        print("Doing pipe conversion of length "..length_of_run)
        if length_of_run >= min_underground_distance
        then
          -- We have a range which we can change into an underground!
          for run_y = start_of_run, y - 1
          do
            pipes[Pos2Str({x=x, y=run_y})] = nil
          end

          num_sections_needed = math.ceil(
            (length_of_run+1)/(max_underground_distance+1)
          )
          for i = 0,num_sections_needed-1
          do
            section_start = start_of_run + round(
              length_of_run*i/num_sections_needed)
            section_end = start_of_run + round(
              length_of_run*(i+1)/num_sections_needed) - 1
            table.insert(
              undergrounds,
              {
                pos={ x=x, y=section_start },
                direction=defines.direction.north
              }
            )
            table.insert(
              undergrounds,
              { pos={ x=x, y=section_end }, direction=defines.direction.south }
            )
          end
        end
        start_of_run = nil
      end
    end
  end

  return {
    directions = directions,
    pipes = pipes,
    undergrounds = undergrounds,
  }
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

  local pipe_type = "pipe"
  local underground_pipe_type = "pipe-to-ground"
  local pumpjack_type = "pumpjack"
  local min_underground_distance = 3

  local max_underground_distance = game.entity_prototypes[underground_pipe_type].max_underground_distance

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
        forbidden_points[Pos2Str({ x = pos.x + off_x, y = pos.y + off_y})] = true
      end
    end

    min_x = math.min(min_x, pos.x - 2)
    min_y = math.min(min_y, pos.y - 2)
    max_x = math.max(max_x, pos.x + 2)
    max_y = math.max(max_y, pos.y + 2)
  end

  AddForbiddenPoints{
    forbidden=forbidden_points,
    force=player.force,
    surface=surface,
    min_x=min_x,
    min_y=min_y,
    max_x=max_x,
    max_y=max_y
  }

  result = FindPipePaths{
    min_x=min_x,
    min_y=min_y,
    max_x=max_x,
    max_y=max_y,
    targets=out_pipe_sets,
    forbidden=forbidden_points,
    min_underground_distance=min_underground_distance,
    max_underground_distance=max_underground_distance,
    debug=player.print
  }

  if result == nil
  then
    player.print("Search for pipe layout failed")
    return
  end

  local directions = result.directions
  local pipes = result.pipes
  local undergrounds = result.undergrounds

  print("Got directions "..serpent.line(directions))
  assert(#oil_patches == #directions, "Did not get one direction per patch\n"
  ..serpent.line(oil_patches).."\n"..serpent.line(directions))

  local direction_array = {
    defines.direction.north,
    defines.direction.east,
    defines.direction.south,
    defines.direction.west,
  }

  for i, patch in pairs(oil_patches)
  do
    local position = patch.position
    local dir_index = directions[i]
    local direction = direction_array[dir_index]
    print("Using direction "..direction.." for patch at "..serpent.line(position))
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

  for _, underground_info in pairs(undergrounds)
  do
    local pos = underground_info.pos
    local direction = underground_info.direction

    surface.create_entity{
      name="entity-ghost",
      inner_name="pipe-to-ground",
      position=pos,
      direction=direction,
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
