local gui = {}

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
  --  tooltip=oop_util.wrap_tooltip{"oop.advanced_settings"},
  --  tags={oop_advanced_settings=true},
  --}

  --do -- Miner selection
  --  local table_root, section = create_setting_section(player_data, frame, "miner")
  --end

  do -- Electric pole selection
    create_setting_section(player_data, frame, "pole")
  end
end

function gui.show_interface(player, player_data)
  local frame = player.gui.screen["oop_settings_frame"]
  if frame then
    frame.visible = true
  else
    gui.create_interface(player, player_data)
  end
  --update_selections(player)
end

function gui.hide_interface(player, player_data)
  local frame = player.gui.screen["oop_settings_frame"]
  if frame then
    frame.visible = false
  end
end

return gui
