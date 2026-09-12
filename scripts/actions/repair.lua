-- keep_repaired: persistent maintenance duty. The companion finds damaged
-- friendly structures, walks to a nearby friendly chest for repair packs when
-- necessary, then walks back and repairs the structure. No items are created.
local companion = require("scripts.companion")
local approach = require("scripts.actions.approach")
local chat = require("scripts.chat")
local events = require("scripts.events")
local reservations = require("scripts.reservations")

local M = {}

local DEFAULT_RADIUS = 256
local MAX_RADIUS = 512
local SCAN_INTERVAL_TICKS = 120
local HEAL_PER_TICK = 3
local HP_PER_REPAIR_PACK = 150
local MAX_REPAIR_PACK_BATCH = 20

local function T(zh, en)
  return storage.local_language == "en" and en or zh
end

local function dist_sq(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

local function health_values(entity)
  local hp, max
  pcall(function()
    hp = entity.health
    max = entity.max_health
  end)
  return hp, max
end

local function needs_repair(entity, force)
  if not (entity and entity.valid and entity.force == force) then return false end
  if entity.type == "character" or entity.type == "entity-ghost" then return false end
  local hp, max = health_values(entity)
  return hp ~= nil and max ~= nil and hp > 0 and hp < max
end

local function find_repair_pack_chest(c, center, radius, blocked)
  local best, best_d
  for _, box in ipairs(c.surface.find_entities_filtered({
    position = center,
    radius = radius,
    force = c.force,
    type = { "container", "logistic-container" },
  })) do
    local inv = box.get_inventory(defines.inventory.chest)
    local blocked_until = box.unit_number and blocked and blocked[box.unit_number]
    if inv and inv.get_item_count("repair-pack") > 0
        and (not blocked_until or game.tick >= blocked_until) then
      local d = dist_sq(box.position, c.position)
      if not best or d < best_d then best, best_d = box, d end
    end
  end
  return best
end

-- Collect enough packs for a useful maintenance route instead of returning to
-- a chest after every lightly damaged machine. The cap keeps each helper from
-- monopolising a shared repair-pack stockpile, and inventory.insert remains
-- the final capacity limit.
local function repair_pack_batch_need(c, task, state)
  local missing_health = 0
  for _, entity in ipairs(c.surface.find_entities_filtered({
    position = state.anchor,
    radius = task.radius,
    force = c.force,
  })) do
    if needs_repair(entity, c.force)
        and reservations.available(entity, companion.context(), task.id) then
      local hp, max = health_values(entity)
      missing_health = missing_health + math.max(0, (max or 0) - (hp or 0))
    end
  end
  return math.max(1, math.min(MAX_REPAIR_PACK_BATCH,
    math.ceil(missing_health / HP_PER_REPAIR_PACK)))
end

function M.start(task)
  local c = companion.require_companion()
  local anchor = (task.center and type(task.center.x) == "number") and task.center or c.position
  task.radius = math.max(8, math.min(tonumber(task.radius) or DEFAULT_RADIUS, MAX_RADIUS))
  task.max_empty_scans = task.max_empty_scans and math.max(1, math.floor(tonumber(task.max_empty_scans))) or nil
  task._repair = {
    anchor = { x = anchor.x, y = anchor.y },
    next_scan = 0,
    repaired = 0,
    empty_scans = 0,
    heal_debt = 0,
    warned_empty = false,
    unreachable = {},
    unreachable_supply = {},
  }
end

function M.tick(task)
  local c = companion.get()
  if not c then return { status = "failed", detail = "the companion character is gone" } end
  local state = task._repair
  state.unreachable_supply = state.unreachable_supply or {} -- migrate an in-progress older repair task

  local target = state.target
  if target and target.valid and needs_repair(target, c.force) then
    if not reservations.claim(target, companion.context(), task.id) then
      state.target, state.supply = nil, nil
      task._approach = nil
      return nil
    end
    if c.get_item_count("repair-pack") == 0 then
      local box = state.supply
      if not (box and box.valid) then
        box = find_repair_pack_chest(c, state.anchor, task.radius, state.unreachable_supply)
        state.supply = box
        task._approach = nil
      end
      if box then
        local reached_box = approach.ensure(task, c, box.position, c.reach_distance)
        if type(reached_box) == "table" then
          if box.unit_number then state.unreachable_supply[box.unit_number] = game.tick + 3600 end
          state.supply = nil
          task._approach = nil
          return nil
        end
        if reached_box ~= "ok" then return nil end
        local inv = box.get_inventory(defines.inventory.chest)
        local available = inv and inv.get_item_count("repair-pack") or 0
        local packs_needed = repair_pack_batch_need(c, task, state)
        local moved = 0
        if available > 0 then
          moved = c.get_main_inventory().insert({
            name = "repair-pack",
            count = math.min(available, packs_needed),
          })
          if moved > 0 then inv.remove({ name = "repair-pack", count = moved }) end
          if moved > 0 then
            local rec = companion.record()
            if rec then rec.repair_no_supply_until = nil end
          end
        end
        state.supply = nil
        task._approach = nil
        return nil
      end

      if not state.warned_empty then
        state.warned_empty = true
        local text = T("发现受损设备，但助手背包和整个工作区域的己方箱子中都没有可用修理包。",
          "Damaged machines were found, but no usable repair packs exist in the companion inventory or friendly chests across the work area.")
        pcall(chat.say, { text = text })
        pcall(events.push, "supply_warning", text)
      end
      state.target = nil
      reservations.release(target, task.id)
      local rec = companion.record()
      if rec then rec.repair_no_supply_until = game.tick + 30 * 60 end
      if task.max_empty_scans then
        return { status = "done", detail = T("工作区域没有可用修理包，已跳过维修并继续其他工作",
          "No repair packs are available in the work area; skipped repairs and continued with other work") }
      end
      state.next_scan = game.tick + SCAN_INTERVAL_TICKS
      return nil
    end

    local reached = approach.ensure(task, c, target.position, c.reach_distance)
    if type(reached) == "table" then
      if target.unit_number then state.unreachable[target.unit_number] = game.tick + 3600 end
      reservations.release(target, task.id)
      state.target = nil
      task._approach = nil
      return nil
    end
    if reached ~= "ok" then return nil end

    state.warned_empty = false
    local hp, max = health_values(target)
    if not hp or not max or hp >= max then
      reservations.release(target, task.id)
      state.target = nil
      task._approach = nil
      return nil
    end
    target.health = math.min(max, hp + HEAL_PER_TICK)
    state.heal_debt = state.heal_debt + HEAL_PER_TICK
    if state.heal_debt >= HP_PER_REPAIR_PACK then
      state.heal_debt = state.heal_debt - HP_PER_REPAIR_PACK
      c.remove_item({ name = "repair-pack", count = 1 })
    end
    if target.health >= max then
      state.repaired = state.repaired + 1
      reservations.release(target, task.id)
      state.target = nil
      task._approach = nil
    end
    return nil
  end
  if target and target.valid then reservations.release(target, task.id) end
  state.target, state.supply = nil, nil

  if game.tick < state.next_scan then
    c.walking_state = { walking = false }
    return nil
  end
  state.next_scan = game.tick + SCAN_INTERVAL_TICKS

  local best, best_d
  for _, entity in ipairs(c.surface.find_entities_filtered({
    position = state.anchor,
    radius = task.radius,
    force = c.force,
  })) do
    local blocked_until = entity.unit_number and state.unreachable[entity.unit_number]
    if needs_repair(entity, c.force) and (not blocked_until or game.tick >= blocked_until)
        and reservations.available(entity, companion.context(), task.id) then
      local d = dist_sq(entity.position, c.position)
      if not best or d < best_d then best, best_d = entity, d end
    end
  end
  state.target = best
  if best then
    reservations.claim(best, companion.context(), task.id)
    state.empty_scans = 0
  elseif task.max_empty_scans then
    state.empty_scans = state.empty_scans + 1
    if state.empty_scans >= task.max_empty_scans then
      return { status = "done", detail = T("当前没有需要维修的己方设备", "No friendly machines currently need repairs") }
    end
  end
  return nil
end

function M.has_work(c, radius, center)
  local rec = companion.record()
  if rec and rec.repair_no_supply_until and game.tick < rec.repair_no_supply_until then
    return false
  end
  radius = math.max(8, math.min(tonumber(radius) or DEFAULT_RADIUS, MAX_RADIUS))
  for _, entity in ipairs(c.surface.find_entities_filtered({
    position = center or c.position,
    radius = radius,
    force = c.force,
  })) do
    if needs_repair(entity, c.force) then return true end
  end
  return false
end

return M
