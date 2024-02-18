data:extend(
{
  {
    type = "selection-tool",
    name = "oil-outpost-planner",
    icon = "__base__/graphics/icons/blueprint.png",
    flags = { "not-stackable", "spawnable" },
    subgroup = "tool",
    order = "c[automated-construction]-b[oil-outpost-planner]",
    stack_size = 1,
    icon_size = 64, icon_mipmaps = 4,
    selection_color = { r = 0.5, g = 0.5, b = 0.5 },
    alt_selection_color = { r = 0, g = 0, b = 1 },
    selection_mode = { "any-entity" },
    alt_selection_mode = { "any-entity" },
    selection_cursor_box_type = "entity",
    alt_selection_cursor_box_type = "entity"
  },
  {
    type = "shortcut",
    name = "oil-outpost-planner",
    order = "o[oil-outpost-planner]",
    action = "spawn-item",
    item_to_spawn = "oil-outpost-planner",
    toggleable = true,
    icon =
    {
      filename = "__base__/graphics/icons/blueprint.png",
      priority = "extra-high-no-scale",
      size = 64,
      scale = 1,
      flags = { "icon" }
    },
    small_icon =
    {
      filename = "__base__/graphics/icons/blueprint.png",
      priority = "extra-high-no-scale",
      size = 64,
      scale = 1,
      flags = { "icon" }
    },
    disabled_small_icon =
    {
      filename = "__base__/graphics/icons/blueprint.png",
      priority = "extra-high-no-scale",
      size = 64,
      scale = 1,
      flags = { "icon" }
    }
  }
})
