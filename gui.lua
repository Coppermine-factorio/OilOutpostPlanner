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
  local section = root.add{type="flow", direction="vertical"}
  player_data.gui.section[name] = section
  section.add{
    type="label",
    style="subheader_caption_label",
    caption={"oil-outpost-planner.settings_"..name.."_label"}
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

  --do -- Miner selection
  --  local table_root, section = create_setting_section(player_data, frame, "miner")
  --end

  do -- Electric pole selection
    create_setting_section(player_data, frame, "pole")
  end
end

local function update_pole_selection(player_data)
  local choices = player_data.choices

  local values = {}
  table.insert(values, {
    value="none",
    tooltip={"oil-outpost-planner.choice_none"},
    icon="oop_no_entity",
    order="",
  })

  local existing_choice_is_valid = ("none" == choices.pole_choice)
  local poles = game.get_filtered_entity_prototypes{
    { filter="type", type="electric-pole" }
  }
  for _, pole in pairs(poles) do
    if pole.flags and pole.flags.hidden then goto skip_pole end
    if blacklist[pole.name] then goto skip_pole end
    local cbox = pole.collision_box
    local size = math.ceil(cbox.right_bottom.x - cbox.left_top.x)
    local supply_area = pole.supply_area_distance
    if size > 1 then goto skip_pole end

    table.insert(values, {
      value=pole.name,
      tooltip=pole.localised_name,
      icon=("entity/"..pole.name),
      order=pole.order,
    })
    if pole.name == choices.pole_choice
    then
      existing_choice_is_valid = true
    end

    ::skip_pole::
  end

  if not existing_choice_is_valid then
    choices.pole_choice = "none"
  end

  local table_root = player_data.gui.tables["pole"]
  create_setting_selector(
    player_data, table_root, "oop_action", "pole", values
  )
end

local function update_selections(player, player_data)
  --update_miner_selection(player_data)
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
