common = {}

function common.get_visible_qualities()
  local qualities = {}

  for _, quality in pairs(prototypes.quality) do
    if not quality.hidden then
      table.insert(qualities, quality)
    end
  end

  return qualities
end

function common.get_unlocked_qualities(force)
  local qualities = {}

  for _, quality in pairs(common.get_visible_qualities()) do
    if force.is_quality_unlocked(quality) then
      table.insert(qualities, quality)
    end
  end

  return qualities
end

function common.get_default_quality()
  return common.get_visible_qualities()[1]
end

common.simple_entity_selections = {
  {
    name="pipe",
    filter_type="pipe",
    default="pipe",
    max_size=1,
    allow_none=false
  },
  {
    name="pipe-to-ground",
    filter_type="pipe-to-ground",
    default="pipe-to-ground",
    max_size=1,
    allow_none=true
  },
  {
    name="pole",
    filter_type="electric-pole",
    default="medium-electric-pole",
    max_size=2,
    allow_none=true
  },
  {
    name="heat-pipe",
    filter_type="heat-pipe",
    default="heat-pipe",
    max_size=1,
    allow_none=true
  },
}

return common
