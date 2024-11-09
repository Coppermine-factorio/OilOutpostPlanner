local graphics = "__OilOutpostPlanner__/graphics/"

data:extend(
{
  {
    type = "selection-tool",
    name = "oil-outpost-planner",
    icon = graphics.."oil-outpost-planner.png",
    flags = { "only-in-cursor", "not-stackable", "spawnable" },
    hidden = true,
    subgroup = "tool",
    order = "c[automated-construction]-e[oil-outpost-planner]",
    stack_size = 1,
    icon_size = 64,
    select = {
      border_color = { r = 0.5, g = 0.5, b = 0.5 },
      mode = { "any-entity" },
      cursor_box_type = "entity",
      entity_filter_mode = "whitelist",
      entity_type_filters = { "resource" },
    },
    alt_select = {
      border_color = { r = 0, g = 0, b = 1 },
      mode = { "any-entity" },
      cursor_box_type = "entity",
    },
  },
  {
    type = "custom-input",
    name = "oil-outpost-planner-keybind",
    key_sequence = "CONTROL + O",
    action = "spawn-item",
    item_to_spawn = "oil-outpost-planner",
  },
  {
    type = "shortcut",
    name = "oil-outpost-planner",
    order = "b[blueprints]-o[oil-outpost-planner]",
    action = "spawn-item",
    item_to_spawn = "oil-outpost-planner",
    associated_control_input = "oil-outpost-planner-keybind",
    style = "blue",
    icon = graphics.."oil-outpost-planner-shortcut.png",
    icon_size = 32,
    small_icon = graphics.."oil-outpost-planner-shortcut.png",
    small_icon_size = 32,
    --disabled_small_icon =
    --{
    --  filename = graphics.."oil-outpost-planner-shortcut.png",
    --  priority = "extra-high-no-scale",
    --  size = 32,
    --  scale = 1,
    --  flags = { "icon" }
    --}
  },
  {
    type = "sprite",
    name = "oop_no_entity",
    filename = graphics.."no-entity.png",
    size = 64,
    mipmap_count = 3,
    flags = { "icon" },
  },
})
