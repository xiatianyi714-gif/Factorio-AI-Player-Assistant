-- Persistent per-machine input targets configured from the relative GUI.
-- Idle companions turn unmet rules into ordinary physical supply_input tasks.
local companion = require("scripts.companion")
local reservations = require("scripts.reservations")

local M = {}
local CHEST_TYPES = { "container", "logistic-container" }

local function rules()
  storage.machine_supply_rules = storage.machine_supply_rules or {}
  return storage.machine_supply_rules
end

local function key(entity)
  return entity and entity.valid and entity.unit_number
end

function M.supported(entity)
  return entity and entity.valid and entity.unit_number and entity.force == game.forces.player
    and (entity.type == "furnace" or entity.type == "assembling-machine"
      or entity.type == "lab" or entity.type == "rocket-silo")
end

function M.configure(entity, item, target)
  if not M.supported(entity) then error("该设备不支持自动投料清单") end
  if type(item) ~= "string" or not prototypes.item[item] then error("请选择要投入的物品") end
  target = math.max(1, math.min(1000, math.floor(tonumber(target) or 1)))
  local id = key(entity)
  local rec = rules()[id] or { entity = entity, items = {} }
  rec.entity, rec.items[item] = entity, target
  rules()[id] = rec
  return target
end

function M.remove(entity, item)
  local id = key(entity)
  local rec = id and rules()[id]
  if not rec then return false end
  rec.items[item] = nil
  if not next(rec.items) then rules()[id] = nil end
  return true
end

function M.list(entity)
  local rec = key(entity) and rules()[key(entity)]
  local out = {}
  for item, target in pairs(rec and rec.items or {}) do
    out[#out + 1] = { item = item, target = target }
  end
  table.sort(out, function(a, b) return a.item < b.item end)
  return out
end

local function has_stock(c, item, center, radius)
  if c.get_main_inventory().get_item_count(item) > 0 then return true end
  for _, box in ipairs(c.surface.find_entities_filtered({
    position = center, radius = radius, force = c.force, type = CHEST_TYPES,
  })) do
    local inv = box.get_inventory(defines.inventory.chest)
    if inv and inv.get_item_count(item) > 0 then return true end
  end
  return false
end

function M.find_task(c, radius, center)
  local best, best_item, best_need, best_d
  for id, rec in pairs(rules()) do
    local entity = rec.entity
    if not (entity and entity.valid) then
      rules()[id] = nil
    elseif entity.surface == c.surface and entity.force == c.force then
      local dx, dy = entity.position.x - center.x, entity.position.y - center.y
      local d = dx * dx + dy * dy
      if d <= radius * radius and reservations.available(entity, companion.context()) then
        for item, target in pairs(rec.items or {}) do
          local current = entity.get_item_count(item)
          local accepts = current > 0
          pcall(function() accepts = accepts or entity.can_insert({ name = item, count = 1 }) end)
          if current < target and accepts and has_stock(c, item, center, radius)
              and (not best_d or d < best_d) then
            best, best_item, best_need, best_d = entity, item, target - current, d
          end
        end
      end
    end
  end
  if not best then return nil end
  return {
    type = "supply_input", item = best_item, count = best_need,
    target = { x = best.position.x, y = best.position.y }, target_entity = best,
    find_in_chests = true, material_search_radius = radius,
    reservation_key = reservations.key(best), configured_machine = true,
  }
end

return M
