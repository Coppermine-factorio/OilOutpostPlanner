local blacklist = require("blacklist")
local common = require("common")

local gui = {}

local function wrap_tooltip(tooltip)
  return tooltip and {"", "     ", tooltip}
end

local function create_setting_section(player_data, root, name, opts)
  opts = opts or {}
  local caption = opts.caption or {"oil-outpost-planner.settings_"..name.."_label"}
  local column_count = opts.column_count or 10
  local width = math.max(column_count * 40, 150)

  local section = root.add{type="flow", direction="vertical"}
  player_data.gui.section[name] = section
  local subheading = section.add{
    type="label",
    style="subheader_caption_label",
    caption=caption
  }
  subheading.style.single_line = false
  subheading.style.maximal_width = width
  local this_row = section.add{
    type="flow",
    direction="vertical",
  }
  local qualities = common.get_visible_qualities()
  if #qualities > 0
  then
    local selected_quality = player_data.qualities[name]
    if selected_quality == nil
    then
      selected_quality = qualities[1]
    end

    local quality_root = this_row.add{
      type="table",
      direction=opts.direction or "horizontal",
      style="slot_table",
      column_count=column_count,
    }

    quality_buttons = {}

    for _, quality in pairs(qualities)
    do
      local quality_button = quality_root.add{
        type="sprite-button",
        tooltip=wrap_tooltip(quality.localised_name),
        style="tool_button_without_padding",
        tags={
          oop_set_quality=name,
          value=quality.name,
        },
      }
      local sprite = quality_button.add{
        type="sprite",
        resize_to_sprite=false,
        sprite="quality/"..quality.name,
        ignored_by_interaction=true,
      }
      -- I tried to set this size relative to the size of the style used for
      -- quality_button, but I can't seem to access that information.
      sprite.style.size = 20
      quality_button.visible = false
      quality_button.toggled = selected_quality == quality.name
      quality_buttons[quality.name] = quality_button
    end

    player_data.gui.quality_selections[name] = quality_buttons
  end

  local table_root = this_row.add{
    type="table",
    direction=opts.direction or "horizontal",
    style="filter_slot_table",
    column_count=column_count,
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
        style="slot_sized_button",
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
      }
    else
      local icon = value.icon
      if style_check and value.icon_enabled then icon = value.icon_enabled end
      button = root.add{
        type="sprite-button",
        style="slot_sized_button",
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
      button.toggled = style_check
    end
    action_class[value.value] = button
  end
end

function gui.create_interface(player, player_data)
  local setting = player.mod_settings["oil-outpost-planner-num-columns"]
  local num_columns = setting.value or 10
  num_columns = math.max(1, num_columns)

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

  local scroll_pane = frame.add{
    type="scroll-pane",
    name="scroll_pane",
  }
  --player_gui.advanced_settings = titlebar.add{
  --  type="sprite-button",
  --  style=style_helper_advanced_toggle(player_data.advanced),
  --  sprite="oop_advanced_settings",
  --  tooltip=wrap_tooltip{"oop.advanced_settings"},
  --  tags={oop_advanced_settings=true},
  --}

  -- Pumpjack selection
  local resource_protos = prototypes.get_entity_filtered{
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
      scroll_pane,
      resource_type.."_pumpjack",
      { caption=caption, column_count=num_columns }
    )
  end

  for _, simple_entity_selection in pairs(common.simple_entity_selections)
  do
    create_setting_section(
      player_data,
      scroll_pane,
      simple_entity_selection.name,
      { column_count=num_columns }
    )
  end
end

local function update_pumpjack_selection(player_data)
  local player_choices = player_data.choices

  local values_by_resource = {}
  local existing_choice_is_valid_by_resource = {}
  local all_miners = prototypes.get_entity_filtered{
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
  local entity_selection = args.entity_selection
  local filter_type = entity_selection.filter_type
  local max_size = entity_selection.max_size
  local table_key = entity_selection.name
  local predicate = entity_selection.predicate
  local allow_none = entity_selection.allow_none

  --args.debug("filter_type = "..filter_type..", max_size = "..max_size)

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
    existing_choice_is_valid = ("none" == existing_choice)
  end

  local entity_protos = prototypes.get_entity_filtered{
    { filter="type", type=filter_type }
  }
  for _, entity_proto in pairs(entity_protos) do
    if entity_proto.hidden
      or entity_proto.has_flag("not-blueprintable")
      or not entity_proto.has_flag("player-creation")
    then
      goto skip_entity_proto
    end

    if blacklist[entity_proto.name] then goto skip_entity_proto end
    local cbox = entity_proto.collision_box
    local size = math.ceil(cbox.right_bottom.x - cbox.left_top.x)
    if size > max_size
    then
      goto skip_entity_proto
    end

    if predicate and not predicate(entity_proto)
    then
      goto skip_entity_proto
    end

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

local function update_quality_visibility(force, player_data)
  local unlocked_qualities = common.get_unlocked_qualities(force)
  local any_visible = #unlocked_qualities > 1

  for _, quality_buttons in pairs(player_data.gui.quality_selections)
  do
    for quality_name, button in pairs(quality_buttons)
    do
      button.visible = any_visible and force.is_quality_unlocked(quality_name)
    end
  end
end

local function update_selections(player, player_data)
  update_pumpjack_selection(player_data)

  for _, simple_entity_selection in pairs(common.simple_entity_selections)
  do
    update_entity_selection{
      player_data=player_data,
      entity_selection=simple_entity_selection,
      debug=player.print,
    }
  end

  update_quality_visibility(player.force, player_data)
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

    player_data.gui.selections[action][last_value].toggled = false
    event.element.toggled = true
    player_data.choices[action.."_choice"] = value
  elseif evt_ele_tags["oop_set_quality"] then
    local name = evt_ele_tags["oop_set_quality"]
    local value = evt_ele_tags["value"]
    local last_value = player_data.qualities[name]

    if last_value == nil
    then
      last_value = common.get_default_quality().name
    end

    player_data.gui.quality_selections[name][last_value].toggled = false
    event.element.toggled = true
    player_data.qualities[name] = value
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
    event.element.toggled = not last_value
    if evt_ele_tags.refresh then update_selections(player) end
  end
end

return gui
