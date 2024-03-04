local blacklist = require("blacklist")

local gui = {}

local function style_helper_selection(check)
  if check then return "yellow_slot_button" end
  return "recipe_slot_button"
end

local function wrap_tooltip(tooltip)
  return tooltip and {"", "     ", tooltip}
end

local function create_setting_section(player_data, root, name, opts)
  opts = opts or {}
  caption = opts.caption or {"oil-outpost-planner.settings_"..name.."_label"}
  local section = root.add{type="flow", direction="vertical"}
  player_data.gui.section[name] = section
  section.add{
    type="label",
    style="subheader_caption_label",
    caption=caption
  }
  local table_root = section.add{
    type="table",
    direction=opts.direction or "horizontal",
    style="filter_slot_table",
    column_count=opts.column_count or 6,
  }
  player_data.gui.tables[name] = table_root
  return table_root, section
end

local function create_setting_selector(
  player_data, root, action_type, action, values
)
  local action_class = {}
  player_data.gui.selections[action] = action_class
  root.clear()
  local selected = player_data.choices[action.."_choice"]

  table.sort(values, function(l, r) return l.order < r.order end)

  for _, value in ipairs(values) do
    local action_type_override = value.action or action_type
    local toggle_value = (
      action_type == "oop_toggle"
      and player_data.choices[value.value.."_choice"])
    local style_check = value.value == selected or toggle_value
    local button
    if value.type == "choose-elem-button" then
      button = root.add{
        type="choose-elem-button",
        style=style_helper_selection(),
        tooltip=wrap_tooltip(value.tooltip),
        elem_type=value.elem_type,
        elem_filters=value.elem_filters,
        item=value.elem_value, -- duplicate them all;
        entity=value.elem_value, -- and let Wube sort them out
        tags={
          [action_type_override]=action,
          value=value.value,
          default=value.default
        },
      }
      local fake_placeholder = button.add{
        type="sprite",
        sprite=value.icon,
        ignored_by_interaction=true,
        style="oop_fake_item_placeholder",
        visible=not value.elem_value,
      }
    else
      local icon = value.icon
      if style_check and value.icon_enabled then icon = value.icon_enabled end
      button = root.add{
        type="sprite-button",
        style=style_helper_selection(style_check),
        sprite=icon,
        tags={
          [action_type_override]=action,
          value=value.value,
          default=value.default,
          refresh=value.refresh,
          oop_icon_default=value.icon,
          oop_icon_enabled=value.icon_enabled,
        },
        tooltip=wrap_tooltip(value.tooltip),
      }
    end
    action_class[value.value] = button
  end
end

function gui.create_interface(player, player_data)
  local frame = player.gui.screen.add{
    type="frame",
    name="oop_settings_frame",
    direction="vertical"
  }
  local player_gui = player_data.gui

  local titlebar = frame.add{
    type="flow",
    name="oop_titlebar",
    direction="horizontal"
  }
  titlebar.add{
    type="label",
    style="frame_title",
    name="oop_titlebar_label",
    caption={"oil-outpost-planner.settings_frame"}
  }
  titlebar.add{
    type="empty-widget",
    name="oop_titlebar_spacer",
    horizontally_strechable=true
  }
  --player_gui.advanced_settings = titlebar.add{
  --  type="sprite-button",
  --  style=style_helper_advanced_toggle(player_data.advanced),
  --  sprite="oop_advanced_settings",
  --  tooltip=wrap_tooltip{"oop.advanced_settings"},
  --  tags={oop_advanced_settings=true},
  --}

  -- Pumpjack selection
  local resource_protos = game.get_filtered_entity_prototypes{
    {filter="type", type="resource"}
  }
  entities_by_resource_type = {}
  for _, resource_proto in pairs(resource_protos)
  do
    if resource_proto.has_flag("not-on-map")
    then
      goto skip_resource
    end

    if resource_proto.autoplace_specification == nil
    then
      goto skip_resource
    end

    local category = resource_proto.resource_category
    if not category
    then
      goto skip_resource
    end

    local mineable_properties = resource_proto.mineable_properties
    if mineable_properties.products then
      for _, product in ipairs(mineable_properties.products) do
        if product.type == "fluid" then
          if entities_by_resource_type[category] == nil
          then
            entities_by_resource_type[category] = {}
          end
          table.insert(entities_by_resource_type[category], resource_proto.name)
          break
        end
      end
    end

    ::skip_resource::
  end

  for resource_type, entities in pairs(entities_by_resource_type)
  do
    list = { "" }
    for _, entity in pairs(entities)
    do
      if #list > 1
      then
        table.insert(list, ", ")
      end
      table.insert(list, {"entity-name."..entity})
    end

    caption = { "oil-outpost-planner.settings_pumpjack_label", list }
    create_setting_section(
      player_data,
      frame,
      resource_type.."_pumpjack",
      { caption=caption }
    )
  end

  -- Pipe selection
  create_setting_section(player_data, frame, "pipe")

  -- Pipe-to-ground selection
  create_setting_section(player_data, frame, "pipe-to-ground")

  -- Electric pole selection
  create_setting_section(player_data, frame, "pole")
end

local function update_pumpjack_selection(player_data)
  local player_choices = player_data.choices

  local values_by_resource = {}
  local existing_choice_is_valid_by_resource = {}
  local all_miners = game.get_filtered_entity_prototypes{
    {filter="type", type="mining-drill"}
  }

  for _, miner_proto in pairs(all_miners) do
    if blacklist[miner_proto.name] then goto skip_miner end

    local output_fluidboxes = {}
    for _, fluidbox in pairs(miner_proto.fluidbox_prototypes)
    do
      if fluidbox.production_type == "output"
      then
        table.insert(output_fluidboxes, fluidbox)
      end
    end
    if #output_fluidboxes ~= 1 then goto skip_miner end


    for resource, _ in pairs(miner_proto.resource_categories)
    do

      if values_by_resource[resource] == nil
      then
        values_by_resource[resource] = {}
      end

      table.insert(values_by_resource[resource], {
        value=miner_proto.name,
        tooltip=miner_proto.localised_name,
        icon=("entity/"..miner_proto.name),
        order=miner_proto.order,
      })

      local choice_key = resource.."_pumpjack_choice"
      if miner_proto.name == player_choices[choice_key] then
        existing_choice_is_valid_by_resource[resource] = true
      end
    end

    ::skip_miner::
  end

  for resource, values in pairs(values_by_resource)
  do
    local choice_key = resource.."_pumpjack_choice"
    local existing_choice_is_valid =
      existing_choice_is_valid_by_resource[resource]
    if not existing_choice_is_valid and #values > 0 then
      player_choices[choice_key] = values[1].value
    elseif #values == 0 then
      player_choices[choice_key] = "none"
      table.insert(values, {
        value="none",
        tooltip={"oil-outpost-planner.msg_no_valid_pumpjacks"},
        icon="oop_no_entity",
        order="",
      })
    end

    local gui_key = resource.."_pumpjack"
    local table_root = player_data.gui.tables[gui_key]

    if table_root == nil
    then
      -- This can happen when there's a resource extractor for which there's no
      -- corresponding resource entity, like the water pumpjack in some mod.
    else
      create_setting_selector(
        player_data, table_root, "oop_action", gui_key, values
      )
    end
  end
end

local function update_entity_selection(args)
  local player_data = args.player_data
  local filter_type = args.filter_type
  local max_size = max_size
  local table_key = args.table_key
  local allow_none = args.allow_none

  local choices = player_data.choices
  local existing_choice_key = table_key.."_choice"
  local existing_choice = choices[existing_choice_key]
  local existing_choice_is_valid = false

  local values = {}
  if allow_none
  then
    table.insert(values, {
      value="none",
      tooltip={"oil-outpost-planner.choice_none"},
      icon="oop_no_entity",
      order="",
    })
    local existing_choice_is_valid = ("none" == existing_choice)
  end

  local entity_protos = game.get_filtered_entity_prototypes{
    { filter="type", type=filter_type }
  }
  for _, entity_proto in pairs(entity_protos) do
    if entity_proto.has_flag("hidden")
      or entity_proto.has_flag("not-blueprintable")
      or not entity_proto.has_flag("player-creation")
    then
      goto skip_entity_proto
    end

    if blacklist[entity_proto.name] then goto skip_entity_proto end
    local cbox = entity_proto.collision_box
    local size = math.ceil(cbox.right_bottom.x - cbox.left_top.x)
    if size > 1 then goto skip_entity_proto end

    table.insert(values, {
      value=entity_proto.name,
      tooltip=entity_proto.localised_name,
      icon=("entity/"..entity_proto.name),
      order=entity_proto.order,
    })
    if entity_proto.name == existing_choice
    then
      existing_choice_is_valid = true
    end

    ::skip_entity_proto::
  end

  if not existing_choice_is_valid then
    if #values > 0
    then
      choices[existing_choice_key] = values[1].value
    else
      choices[existing_choice_key] = nil
    end
  end

  local table_root = player_data.gui.tables[table_key]
  create_setting_selector(
    player_data, table_root, "oop_action", table_key, values
  )
end

local function update_pole_selection(player_data)
  update_entity_selection{
    player_data=player_data,
    filter_type="electric-pole",
    max_size=1,
    table_key="pole",
    allow_none=true,
  }
end

local function update_pipe_selection(player_data)
  update_entity_selection{
    player_data=player_data,
    filter_type="pipe",
    max_size=1,
    table_key="pipe",
    allow_none=false,
  }
end

local function update_pipe_to_ground_selection(player_data)
  update_entity_selection{
    player_data=player_data,
    filter_type="pipe-to-ground",
    max_size=1,
    table_key="pipe-to-ground",
    allow_none=true,
  }
end

local function update_selections(player, player_data)
  update_pumpjack_selection(player_data)
  update_pipe_selection(player_data)
  update_pipe_to_ground_selection(player_data)
  update_pole_selection(player_data)
end

function gui.show_interface(player, player_data)
  local frame = player.gui.screen["oop_settings_frame"]
  if frame then
    frame.visible = true
  else
    gui.create_interface(player, player_data)
  end
  update_selections(player, player_data)
end

function gui.hide_interface(player, player_data)
  local frame = player.gui.screen["oop_settings_frame"]
  if frame then
    frame.visible = false
  end
end

function gui.on_click(event, player, player_data)
  local evt_ele_tags = event.element.tags
  if evt_ele_tags["oop_action"] then
    local action = evt_ele_tags["oop_action"]
    local value = evt_ele_tags["value"]
    local last_value = player_data.choices[action.."_choice"]

    player_data.gui.selections[action][last_value].style = style_helper_selection(false)
    event.element.style = style_helper_selection(true)
    player_data.choices[action.."_choice"] = value
  elseif evt_ele_tags["oop_toggle"] then
    local action = evt_ele_tags["oop_toggle"]
    local value = evt_ele_tags["value"]
    local last_value = player_data.choices[value.."_choice"]

    if evt_ele_tags.oop_icon_enabled then
      if not last_value then
        event.element.sprite = evt_ele_tags.oop_icon_enabled --[[@as string]]
      else
        event.element.sprite = evt_ele_tags.oop_icon_default --[[@as string]]
      end
    end

    player_data.choices[value.."_choice"] = not last_value
    event.element.style = style_helper_selection(not last_value)
    if evt_ele_tags.refresh then update_selections(player) end
  end
end

return gui
