data:extend(
{
  {
    type = "selection-tool",
    name = "Oil Outpost Generator",
    icon = "__base__/graphics/icons/blueprint.png",
    flags = { "not-stackable", "spawnable" },
    subgroup = "tool",
    order = "c[automated-construction]-b[oil-outpost-generator]",
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
    name = "Oil Outpost Generator",
    order = "o[oil-outpost-generator]",
    action = "spawn-item",
    item_to_spawn = "Oil Outpost Generator",
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
