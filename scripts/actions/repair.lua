-- keep_repaired: persistent maintenance duty. The companion finds damaged
-- friendly structures, walks to a nearby friendly chest for repair packs when
-- necessary, then walks back and repairs the structure. No items are created.
local companion = require("scripts.companion")
local approach = require("scripts.actions.approach")
local chat = require("scripts.chat")
local events = require("scripts.events")

local M = {}

local DEFAULT_RADIUS = 256
local MAX_RADIUS = 512
local CHEST_RADIUS = 96
local SCAN_INTERVAL_TICKS = 120
local HEAL_PER_TICK = 3
local HP_PER_REPAIR_PACK = 150

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

local function find_repair_pack_chest(c, center)
  local best, best_d
  for _, box in ipairs(c.surface.find_entities_filtered({
    position = center,
    radius = CHEST_RADIUS,
    force = c.force,
    type = { "container", "logistic-container" },
  })) do
    local inv = box.get_inventory(defines.inventory.chest)
    if inv and inv.get_item_count("repair-pack") > 0 then
      local d = dist_sq(box.position, c.position)
      if not best or d < best_d then best, best_d = box, d end
    end
  end
  return best
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
  }
end

function M.tick(task)
  local c = companion.get()
  if not c then return { status = "failed", detail = "the companion character is gone" } end
  local state = task._repair

  local target = state.target
  if target and target.valid and needs_repair(target, c.force) then
    if c.get_item_count("repair-pack") == 0 then
      local box = state.supply
      if not (box and box.valid) then
        box = find_repair_pack_chest(c, target.position)
        state.supply = box
        task._approach = nil
      end
      if box then
        local reached_box = approach.ensure(task, c, box.position, c.reach_distance)
        if type(reached_box) == "table" then
          state.supply = nil
          task._approach = nil
          return nil
        end
        if reached_box ~= "ok" then return nil end
        local inv = box.get_inventory(defines.inventory.chest)
        local available = inv and inv.get_item_count("repair-pack") or 0
        local hp, max = health_values(target)
        local packs_needed = math.max(1, math.ceil(math.max(0, (max or 0) - (hp or 0)) / HP_PER_REPAIR_PACK))
        local moved = 0
        if available > 0 then
          moved = c.get_main_inventory().insert({
            name = "repair-pack",
            count = math.min(available, packs_needed),
          })
          if moved > 0 then inv.remove({ name = "repair-pack", count = moved }) end
        end
        state.supply = nil
        task._approach = nil
        return nil
      end

      if not state.warned_empty then
        state.warned_empty = true
        local text = T("发现受损设备，但助手背包和设备附近箱子中都没有修理包。",
          "Damaged machines were found, but there are no repair packs in the companion inventory or nearby friendly chests.")
        pcall(chat.say, { text = text })
        pcall(events.push, "supply_warning", text)
      end
      state.target = nil
      state.next_scan = game.tick + SCAN_INTERVAL_TICKS
      return nil
    end

    local reached = approach.ensure(task, c, target.position, c.reach_distance)
    if type(reached) == "table" then
      if target.unit_number then state.unreachable[target.unit_number] = game.tick + 3600 end
      state.target = nil
      task._approach = nil
      return nil
    end
    if reached ~= "ok" then return nil end

    state.warned_empty = false
    local hp, max = health_values(target)
    if not hp or not max or hp >= max then
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
      state.target = nil
      task._approach = nil
    end
    return nil
  end
  state.target, state.supply = nil, nil

  if game.tick < state.next_scan then
    c.walking_state = { walking = false }
    return nil
  end
  state.next_scan = game.tick + SCAN_INTERVAL_TICKS

  local best, best_d
  for _, entity in ipairs(c.surface.find_entities_filtered({
    position = c.position,
    radius = task.radius,
    force = c.force,
  })) do
    local blocked_until = entity.unit_number and state.unreachable[entity.unit_number]
    if needs_repair(entity, c.force) and (not blocked_until or game.tick >= blocked_until) then
      local d = dist_sq(entity.position, c.position)
      if not best or d < best_d then best, best_d = entity, d end
    end
  end
  state.target = best
  if best then
    state.empty_scans = 0
  elseif task.max_empty_scans then
    state.empty_scans = state.empty_scans + 1
    if state.empty_scans >= task.max_empty_scans then
      return { status = "done", detail = T("当前没有需要维修的己方设备", "No friendly machines currently need repairs") }
    end
  end
  return nil
end

function M.has_work(c, radius)
  radius = math.max(8, math.min(tonumber(radius) or DEFAULT_RADIUS, MAX_RADIUS))
  for _, entity in ipairs(c.surface.find_entities_filtered({
    position = c.position,
    radius = radius,
    force = c.force,
  })) do
    if needs_repair(entity, c.force) then return true end
  end
  return false
end

return M
