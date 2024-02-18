local graphics = "__OilOutpostPlanner__/graphics/"

data:extend(
{
  {
    type = "selection-tool",
    name = "oil-outpost-planner",
    icon = graphics.."oil-outpost-planner.png",
    flags = { "only-in-cursor", "hidden", "not-stackable", "spawnable" },
    subgroup = "tool",
    order = "c[automated-construction]-b[oil-outpost-planner]",
    stack_size = 1,
    icon_size = 64, icon_mipmaps = 4,
    selection_color = { r = 0.5, g = 0.5, b = 0.5 },
    selection_mode = { "any-entity" },
    selection_cursor_box_type = "entity",
    entity_filter_mode = "whitelist",
    entity_type_filters = { "resource" },
    alt_selection_color = { r = 0, g = 0, b = 1 },
    alt_selection_mode = { "any-entity" },
    alt_selection_cursor_box_type = "entity"
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
    icon =
    {
      filename = graphics.."oil-outpost-planner.png",
      priority = "extra-high-no-scale",
      size = 64,
      scale = 1,
      flags = { "icon" }
    },
    small_icon =
    {
      filename = graphics.."oil-outpost-planner.png",
      priority = "extra-high-no-scale",
      size = 64,
      scale = 1,
      flags = { "icon" }
    },
    disabled_small_icon =
    {
      filename = graphics.."oil-outpost-planner.png",
      priority = "extra-high-no-scale",
      size = 64,
      scale = 1,
      flags = { "icon" }
    }
  }
})
