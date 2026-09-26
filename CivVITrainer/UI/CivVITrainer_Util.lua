local Util = {}

function Util.Clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

function Util.SafeNumber(value, fallback)
  if type(value) == "number" then return value end
  return fallback or 0
end

function Util.Copy(source)
  local result = {}
  if source then
    for key, value in pairs(source) do result[key] = value end
  end
  return result
end

function Util.SortedValues(map, compare)
  local values = {}
  for _, value in pairs(map or {}) do table.insert(values, value) end
  table.sort(values, compare)
  return values
end

function Util.Join(parts, separator)
  local kept = {}
  for _, part in ipairs(parts or {}) do
    if part ~= nil and part ~= "" then table.insert(kept, tostring(part)) end
  end
  return table.concat(kept, separator or " ")
end

function Util.Distance(a, b)
  if not a or not b then return 999 end
  if Map and Map.GetPlotDistance then
    return Map.GetPlotDistance(a.x, a.y, b.x, b.y)
  end
  return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

function Util.Try(callable, fallback)
  local ok, value = pcall(callable)
  if ok and value ~= nil then return value end
  return fallback
end

return Util

