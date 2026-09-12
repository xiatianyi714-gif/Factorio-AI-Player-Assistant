-- Shared, physical material collection for construction tasks. Helpers never
-- receive free items: they walk to a same-force chest, take what is available,
-- then return to the construction target on later ticks.
local approach = require("scripts.actions.approach")

local M = {}
local SEARCH_RADIUS = 256

local function distance_sq(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

local function chest_inventory(box)
  if not (box and box.valid) then return nil end
  return box.get_inventory(defines.inventory.chest)
end

local function find_chest(task, c, item_name, center)
  local best, best_distance
  local ignored = task._material_ignored and task._material_ignored[item_name]
  for _, box in ipairs(c.surface.find_entities_filtered({
    position = center or c.position,
    radius = task.material_search_radius or SEARCH_RADIUS,
    force = c.force,
    type = { "container", "logistic-container" },
  })) do
    local unit = box.unit_number or tostring(box)
    local inv = chest_inventory(box)
    if not (ignored and ignored[unit]) and inv and inv.get_item_count(item_name) > 0 then
      local d = distance_sq(c.position, box.position)
      if not best_distance or d < best_distance then
        best, best_distance = box, d
      end
    end
  end
  return best
end

-- Returns "ok" when the helper has the item, "missing" when no stocked chest
-- exists in the construction area, and nil while walking/collecting.
function M.ensure(task, c, item_name, wanted, center)
  -- Work materials must be physically present in the main inventory. Using
  -- LuaControl.get_item_count here also sees equipped ammunition, which could
  -- make a supply task consume the magazine reserved for the companion.
  if c.get_main_inventory().get_item_count(item_name) > 0 then
    task._material_supply = nil
    return "ok"
  end

  local supply = task._material_supply
  if not (supply and supply.item == item_name and supply.box and supply.box.valid) then
    local box = find_chest(task, c, item_name, center)
    if not box then
      task._material_supply = nil
      return "missing"
    end
    task._approach = nil
    supply = { item = item_name, box = box }
    task._material_supply = supply
  end

  local reached = approach.ensure(task, c, supply.box.position, c.reach_distance)
  if type(reached) == "table" then
    task._material_ignored = task._material_ignored or {}
    task._material_ignored[item_name] = task._material_ignored[item_name] or {}
    task._material_ignored[item_name][supply.box.unit_number or tostring(supply.box)] = true
    task._material_supply = nil
    task._approach = nil
    return nil
  end
  if reached ~= "ok" then return nil end

  local inv = chest_inventory(supply.box)
  local available = inv and inv.get_item_count(item_name) or 0
  local request = math.max(1, math.floor(tonumber(wanted) or 1))
  local moved = 0
  if available > 0 then
    moved = c.get_main_inventory().insert({ name = item_name, count = math.min(available, request) })
    if moved > 0 then inv.remove({ name = item_name, count = moved }) end
  end
  task._material_supply = nil
  task._approach = nil
  if moved > 0 then return "ok" end
  return nil
end

return M
