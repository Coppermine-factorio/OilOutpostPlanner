util = {}

function util.get_visible_qualities()
  local qualities = {}

  for _, quality in pairs(prototypes.quality) do
    if not quality.hidden then
      table.insert(qualities, quality)
    end
  end

  return qualities
end

function util.get_unlocked_qualities(force)
  local qualities = {}

  for _, quality in pairs(util.get_visible_qualities()) do
    if force.is_quality_unlocked(quality) then
      table.insert(qualities, quality)
    end
  end

  return qualities
end

function util.get_default_quality()
  return util.get_visible_qualities()[1]
end

return util
