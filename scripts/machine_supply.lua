-- Persistent per-machine input targets configured from the relative GUI.
-- Idle companions turn unmet rules into ordinary physical supply_input tasks.
local companion = require("scripts.companion")
local reservations = require("scripts.reservations")

local M = {}
local CHEST_TYPES = { "container", "logistic-container" }
local category_inputs

local function distance_sq(a, b)
  local x, y = a.x - b.x, a.y - b.y
  return x * x + y * y
end

local function rules()
  storage.machine_supply_rules = storage.machine_supply_rules or {}
  return storage.machine_supply_rules
end

local function chest_rules()
  storage.output_chest_rules = storage.output_chest_rules or {}
  return storage.output_chest_rules
end

local function key(entity)
  return entity and entity.valid and entity.unit_number
end

function M.supported(entity)
  return entity and entity.valid and entity.unit_number and entity.force == game.forces.player
    and (entity.type == "furnace" or entity.type == "assembling-machine"
      or entity.type == "lab" or entity.type == "rocket-silo")
end

function M.supported_chest(entity)
  return entity and entity.valid and entity.unit_number and entity.force == game.forces.player
    and (entity.type == "container" or entity.type == "logistic-container")
end

function M.configure_chest(entity, item)
  if not M.supported_chest(entity) then error("该箱子不支持助手收纳清单") end
  if type(item) ~= "string" or not prototypes.item[item] then error("请选择这个箱子要接收的物品") end
  local id = key(entity)
  local rec = chest_rules()[id]
  if type(rec) ~= "table" then rec = { entity = entity, items = {} } end
  rec.entity = entity
  rec.items[item] = true
  chest_rules()[id] = rec
  return true
end

function M.remove_chest_item(entity, item)
  local id = key(entity)
  local rec = id and chest_rules()[id]
  if type(rec) ~= "table" then return false end
  rec.items[item] = nil
  if not next(rec.items) then chest_rules()[id] = nil end
  return true
end

function M.list_chest(entity)
  local rec = key(entity) and chest_rules()[key(entity)]
  local out = {}
  for item in pairs(type(rec) == "table" and rec.items or {}) do out[#out + 1] = item end
  table.sort(out)
  return out
end

local function recipe_uses(recipe, item)
  for _, ingredient in ipairs(recipe and recipe.ingredients or {}) do
    if ingredient.type == "item" and ingredient.name == item then return true end
  end
  return false
end

local function inputs_by_category()
  if category_inputs then return category_inputs end
  category_inputs = {}
  for _, recipe in pairs(prototypes.recipe) do
    local category = recipe.category or "crafting"
    category_inputs[category] = category_inputs[category] or {}
    for _, ingredient in ipairs(recipe.ingredients or {}) do
      if ingredient.type == "item" then category_inputs[category][ingredient.name] = true end
    end
  end
  return category_inputs
end

-- Strictly identify production ingredients. LuaEntity.insert also accepts
-- fuel and modules, so it cannot be used alone to decide what belongs in a
-- recipe input list.
function M.accepts_input(entity, item)
  if not (M.supported(entity) and prototypes.item[item]) then return false end
  if entity.type == "lab" then
    local accepted = false
    pcall(function()
      for _, input in pairs(entity.prototype.inputs or {}) do
        local name = type(input) == "string" and input or input.name
        if name == item then accepted = true; break end
      end
    end)
    return accepted
  end

  local recipe
  pcall(function() recipe = entity.get_recipe() end)
  if recipe then return recipe_uses(recipe, item) end
  if entity.type ~= "furnace" then return false end

  local known = inputs_by_category()
  for category in pairs(entity.prototype.crafting_categories or {}) do
    if known[category] and known[category][item] then return true end
  end
  return false
end

function M.configure(entity, item, target, threshold_percent)
  if not M.supported(entity) then error("该设备不支持自动投料清单") end
  if type(item) ~= "string" or not prototypes.item[item] then error("请选择要投入的物品") end
  if not M.accepts_input(entity, item) then
    error("所选物品不是该设备当前配方的原材料；燃料请使用补燃料功能")
  end
  target = math.max(1, math.min(1000, math.floor(tonumber(target) or 1)))
  threshold_percent = math.max(0, math.min(100,
    math.floor(tonumber(threshold_percent) or 25)))
  local id = key(entity)
  local rec = rules()[id]
  if type(rec) ~= "table" then rec = { entity = entity, items = {}, thresholds = {} } end
  rec.thresholds = rec.thresholds or {}
  rec.entity, rec.items[item] = entity, target
  rec.thresholds[item] = threshold_percent
  rules()[id] = rec
  return target
end

function M.remove(entity, item)
  local id = key(entity)
  local rec = id and rules()[id]
  if not rec then return false end
  rec.items[item] = nil
  if rec.thresholds then rec.thresholds[item] = nil end
  if not next(rec.items) then rules()[id] = nil end
  return true
end

function M.list(entity)
  local rec = key(entity) and rules()[key(entity)]
  local out = {}
  for item, target in pairs(rec and rec.items or {}) do
    out[#out + 1] = { item = item, target = target,
      threshold = (rec.thresholds and rec.thresholds[item]) or 25,
      compatible = M.accepts_input(entity, item) }
  end
  table.sort(out, function(a, b) return a.item < b.item end)
  return out
end

function M.is_configured(entity)
  local rec = key(entity) and rules()[key(entity)]
  return type(rec) == "table" and next(rec.items or {}) ~= nil
end

function M.has_rule(entity, item)
  local rec = key(entity) and rules()[key(entity)]
  return type(rec) == "table" and type(rec.items) == "table" and rec.items[item] ~= nil
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

local function output_blocked(entity, inv)
  local blocked = false
  pcall(function() blocked = entity.status == defines.entity_status.full_output end)
  if not blocked then pcall(function() blocked = inv and inv.is_full() end) end
  return blocked
end

local function find_carried_storage_task(c, radius, center)
  local main = c.get_main_inventory()
  local best, best_item, best_d
  for chest_id, rec in pairs(chest_rules()) do
    local destination = type(rec) == "table" and rec.entity
    if not (destination and destination.valid) then
      chest_rules()[chest_id] = nil
    elseif destination.surface == c.surface and destination.force == c.force then
      local d = distance_sq(destination.position, center)
      if d <= radius * radius and reservations.available(destination, companion.context()) then
        for item in pairs(rec.items or {}) do
          if main.get_item_count(item) > 0 then
            local accepts = false
            pcall(function() accepts = destination.can_insert({ name = item, count = 1 }) end)
            if accepts and (not best_d or d < best_d) then
              best, best_item, best_d = destination, item, d
            end
          end
        end
      end
    end
  end
  if not best then return nil end
  return { type = "supply_input", item = best_item, count = main.get_item_count(best_item),
    target = { x = best.position.x, y = best.position.y }, target_entity = best,
    reservation_key = reservations.key(best), configured_storage = true }
end

local function find_output_task(c, radius, center)
  local best_key, best_d
  for route_key, route in pairs(storage.output_routes or {}) do
    local source, destination = route.source, route.destination
    if not (source and source.valid and destination and destination.valid) then
      storage.output_routes[route_key] = nil
      if storage.output_route_locks then storage.output_route_locks[route_key] = nil end
    elseif M.is_configured(source) and source.surface == c.surface and source.force == c.force
        and destination and destination.valid then
      local d = distance_sq(source.position, center)
      if d <= radius * radius then
        local inv
        pcall(function() inv = source.get_output_inventory() end)
        local full = output_blocked(source, inv)
        if full and inv.get_item_count(route.item) > 0 and (not best_d or d < best_d) then
          best_key, best_d = route_key, d
        end
      end
    end
  end
  if best_key then
    return { type = "output_sort", batch = 1000, route_key = best_key,
      only_when_full = true, one_shot = true }
  end

  -- New global classification rules: a chest declares which products it
  -- accepts, so every configured machine can find it without a per-machine
  -- destination selection.
  local best_route, best_route_d
  for machine_id, rec in pairs(rules()) do
    local source = type(rec) == "table" and rec.entity
    if not (source and source.valid) then
      rules()[machine_id] = nil
    elseif source.surface == c.surface and source.force == c.force then
      local source_d = distance_sq(source.position, center)
      if source_d <= radius * radius then
        local inv
        pcall(function() inv = source.get_output_inventory() end)
        local full = output_blocked(source, inv)
        if full then
          for _, stack in ipairs(inv.get_contents()) do
            for chest_id, chest_rec in pairs(chest_rules()) do
              local destination = chest_rec.entity
              if not (destination and destination.valid) then
                chest_rules()[chest_id] = nil
              elseif chest_rec.items and chest_rec.items[stack.name]
                  and destination.surface == c.surface and destination.force == c.force then
                local accepts = false
                pcall(function() accepts = destination.can_insert({ name = stack.name, count = 1 }) end)
                local route_d = source_d + distance_sq(source.position, destination.position)
                if accepts and (not best_route_d or route_d < best_route_d) then
                  best_route_d = route_d
                  best_route = { source = source, destination = destination, item = stack.name }
                end
              end
            end
          end
        end
      end
    end
  end
  if best_route then
    local auto_key = "auto:" .. tostring(best_route.source.unit_number) .. ":"
      .. best_route.item .. ":" .. tostring(best_route.destination.unit_number)
    return { type = "output_sort", batch = 1000, direct_route = best_route,
      direct_route_key = auto_key, only_when_full = true, one_shot = true }
  end
end

local function find_fuel_task(c, radius, center)
  local best, best_d
  local target_count = storage.autonomy_fuel_target or 10
  local threshold = math.max(0, math.floor(math.min(2, target_count * 0.25)))
  for _, rec in pairs(rules()) do
    local entity = type(rec) == "table" and rec.entity
    if entity and entity.valid and entity.surface == c.surface and entity.force == c.force then
      local d = distance_sq(entity.position, center)
      if d <= radius * radius then
        local fuel_count
        pcall(function() fuel_count = entity.burner and entity.burner.inventory.get_item_count() end)
        if fuel_count ~= nil and fuel_count <= threshold and (not best_d or d < best_d) then
          best, best_d = entity, d
        end
      end
    end
  end
  if best then
    return { type = "keep_fueled", center = center, radius = radius,
      top_up_count = target_count, max_empty_scans = 1, target_entities = { best } }
  end
end

function M.find_task(c, radius, center)
  local carried = find_carried_storage_task(c, radius, center)
  if carried then return carried end
  -- A full output blocks production, so clear it before fetching more input.
  local output = find_output_task(c, radius, center)
  if output then return output end
  local fuel = find_fuel_task(c, radius, center)
  if fuel then return fuel end
  local best, best_item, best_need, best_d
  for id, rec in pairs(rules()) do
    local entity = type(rec) == "table" and rec.entity
    if not (entity and entity.valid) then
      rules()[id] = nil
    elseif entity.surface == c.surface and entity.force == c.force then
      local dx, dy = entity.position.x - center.x, entity.position.y - center.y
      local d = dx * dx + dy * dy
      if d <= radius * radius and reservations.available(entity, companion.context()) then
        for item, target in pairs(rec.items or {}) do
          local current = entity.get_item_count(item)
          local threshold_percent = (rec.thresholds and rec.thresholds[item]) or 25
          local refill_at = math.max(1, math.ceil(target * threshold_percent / 100))
          local accepts = M.accepts_input(entity, item)
          if accepts then
            local room = false
            pcall(function() room = entity.can_insert({ name = item, count = 1 }) end)
            accepts = room or current > 0
          end
          if current < refill_at and current < target and accepts and has_stock(c, item, center, radius)
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
