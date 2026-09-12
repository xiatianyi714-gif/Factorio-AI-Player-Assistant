-- Short autonomous job: obtain compatible ammunition from the companion's
-- inventory or a friendly chest, walk to an ammo turret, and top it up.
local companion = require("scripts.companion")
local approach = require("scripts.actions.approach")
local material_supply = require("scripts.actions.material_supply")

local M = {}
local DEFAULT_RADIUS = 256

local function ammo_inventory(turret)
  if not (turret and turret.valid) then return nil end
  return turret.get_inventory(defines.inventory.turret_ammo)
end

local function accepts(turret, item_name)
  local proto = prototypes.item[item_name]
  if not proto or proto.type ~= "ammo" then return false end
  local inv = ammo_inventory(turret)
  local ok = false
  if inv then pcall(function() ok = inv.can_insert({ name = item_name, count = 1 }) end) end
  return ok
end

local function carried_ammo(c, turret)
  for _, stack in ipairs(c.get_main_inventory().get_contents()) do
    if accepts(turret, stack.name) then return stack.name end
  end
  return nil
end

local function stored_ammo(c, turret, radius)
  for _, box in ipairs(c.surface.find_entities_filtered({
    position = turret.position, radius = radius, force = c.force,
    type = { "container", "logistic-container" },
  })) do
    local inv = box.get_inventory(defines.inventory.chest)
    if inv then
      for _, stack in ipairs(inv.get_contents()) do
        if accepts(turret, stack.name) then return stack.name end
      end
    end
  end
  return nil
end

local function turret_count(turret)
  local inv = ammo_inventory(turret)
  return inv and inv.get_item_count() or 0
end

function M.find_task(c, radius, target_count, center)
  radius = math.max(8, math.min(math.floor(tonumber(radius) or DEFAULT_RADIUS), 512))
  target_count = math.max(1, math.min(math.floor(tonumber(target_count) or 10), 1000))
  local best, best_item, best_distance
  for _, turret in ipairs(c.surface.find_entities_filtered({
    position = center or c.position, radius = radius, force = c.force, type = "ammo-turret",
  })) do
    if turret.valid and turret_count(turret) < target_count then
      local item = carried_ammo(c, turret) or stored_ammo(c, turret, radius)
      if item then
        local dx, dy = turret.position.x - c.position.x, turret.position.y - c.position.y
        local distance = dx * dx + dy * dy
        if not best_distance or distance < best_distance then
          best, best_item, best_distance = turret, item, distance
        end
      end
    end
  end
  if not best then return nil end
  return {
    type = "turret_supply",
    turret = best,
    ammo = best_item,
    target_count = target_count,
    search_radius = radius,
  }
end

function M.start(task)
  companion.require_companion()
  if not (task.turret and task.turret.valid and task.turret.type == "ammo-turret") then
    error("炮塔补弹目标已不存在")
  end
  task.target_count = math.max(1, math.min(math.floor(tonumber(task.target_count) or 10), 1000))
end

function M.tick(task)
  local c = companion.get()
  local turret = task.turret
  if not c then return { status = "failed", detail = "助手已不存在" } end
  if not (turret and turret.valid) then return { status = "failed", detail = "炮塔已不存在" } end
  local current = turret_count(turret)
  if current >= task.target_count then return { status = "done", detail = "炮塔弹药已经充足" } end

  local ammo = carried_ammo(c, turret) or task.ammo
  if c.get_item_count(ammo) == 0 then
    local supplied = material_supply.ensure(task, c, ammo,
      task.target_count - current, turret.position)
    if supplied == nil then return nil end
    if supplied == "missing" then return { status = "failed", detail = "没有找到兼容的炮塔弹药" } end
  end

  local reached = approach.ensure(task, c, turret.position, c.reach_distance)
  if type(reached) == "table" then return reached end
  if reached ~= "ok" then return nil end
  local wanted = math.min(c.get_item_count(ammo), task.target_count - current)
  local inserted = 0
  pcall(function() inserted = ammo_inventory(turret).insert({ name = ammo, count = wanted }) end)
  if inserted > 0 then c.remove_item({ name = ammo, count = inserted }) end
  return inserted > 0
    and { status = "done", detail = string.format("向炮塔补充了 %d 发 %s", inserted, ammo) }
    or { status = "failed", detail = "炮塔拒绝弹药或弹药库存已满" }
end

return M
