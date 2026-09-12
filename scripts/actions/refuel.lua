-- keep_fueled: persistent area caretaker. Scans burner machines around an
-- anchor, walks to any running low and tops them up from the companion's own
-- inventory. Never finishes on its own — cancel/replace ends it.
local companion = require("scripts.companion")
local approach = require("scripts.actions.approach")
local chat = require("scripts.chat")
local events = require("scripts.events")
local mine = require("scripts.actions.mine")

local M = {}

local DEFAULT_RADIUS = 256
local MAX_RADIUS = 512
local FUEL_CHEST_RADIUS = 96
local SCAN_INTERVAL_TICKS = 180
local ROUND_RESTART_TICKS = 600
local TOP_UP_COUNT = 10
local POWER_TYPES = { boiler = true, ["burner-generator"] = true, reactor = true }

local function dist_sq(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

-- Runtime LuaBurner does not expose `fuel_categories`.  Asking its fuel
-- inventory directly is both more reliable and also respects modded burners.
local function compatible_fuel(item_name, burner, preferred)
  if preferred and item_name ~= preferred then return false, 0 end
  local proto = prototypes.item[item_name]
  local value = proto and proto.fuel_value or 0
  if value <= 0 then return false, 0 end
  local accepted = false
  pcall(function()
    accepted = burner.inventory.can_insert({ name = item_name, count = 1 })
  end)
  return accepted, value
end

-- Best compatible fuel already carried by the companion.
local function pick_carried_fuel(c, burner, preferred)
  local best, best_value = nil, 0
  for _, item in ipairs(c.get_main_inventory().get_contents()) do
    local ok, value = compatible_fuel(item.name, burner, preferred)
    if ok and not preferred and item.name == "coal" then return "coal" end
    if ok and value > best_value then
      best, best_value = item.name, value
    end
  end
  return best
end

-- Find the nearest same-force chest containing fuel accepted by this burner.
local function find_fuel_chest(c, burner, preferred, center, radius)
  local best_box, best_fuel, best_d, best_is_coal
  for _, box in ipairs(c.surface.find_entities_filtered({
    position = center,
    radius = radius,
    force = c.force,
    type = { "container", "logistic-container" },
  })) do
    local inv = box.get_inventory(defines.inventory.chest)
    if inv then
      for _, item in ipairs(inv.get_contents()) do
        local compatible = compatible_fuel(item.name, burner, preferred)
        if compatible then
          local d = dist_sq(box.position, c.position)
          local is_coal = not preferred and item.name == "coal"
          if not best_box or (is_coal and not best_is_coal)
              or (is_coal == best_is_coal and d < best_d) then
            best_box, best_fuel, best_d, best_is_coal = box, item.name, d, is_coal
          end
        end
      end
    end
  end
  return best_box, best_fuel
end

local function burner_fuel_count(e)
  local n = nil
  pcall(function()
    local burner = e.burner
    if not burner then return end
    local inv = burner.inventory
    if not inv then return end
    n = inv.get_item_count()
  end)
  return n -- nil = not a (fueled) burner
end

local function is_power_device(e)
  return e and POWER_TYPES[e.type] == true
end

local function fuel_inventory_full(e)
  local full = true
  pcall(function() full = e.burner.inventory.is_full() end)
  return full
end

local function desired_fuel_count(task, e, item_name)
  if not is_power_device(e) then return task.top_up_count end
  local stack_size = (prototypes.item[item_name] and prototypes.item[item_name].stack_size) or task.top_up_count
  local slots = 1
  pcall(function() slots = #e.burner.inventory end)
  return math.max(task.top_up_count, slots * stack_size)
end

local function needs_fuel(e, task)
  local count = burner_fuel_count(e)
  if count == nil then return false end
  if is_power_device(e) then return not fuel_inventory_full(e) end
  return count < task.top_up_count
end

-- Estimate one collection batch for every currently serviceable machine in
-- this helper's work radius. The character inventory still provides the hard
-- capacity limit, so this never creates items or takes more than it can carry.
local function batch_fuel_need(c, task, item_name)
  local total = 0
  for _, e in ipairs(c.surface.find_entities_filtered({
    position = task._rf and task._rf.anchor or c.position,
    radius = task.radius,
    force = c.force,
  })) do
    if e.valid and e.type ~= "character" then
      local count = burner_fuel_count(e)
      if count ~= nil and needs_fuel(e, task) then
        local accepted = compatible_fuel(item_name, e.burner, task.fuel)
        if accepted then
          total = total + math.max(0, desired_fuel_count(task, e, item_name) - count)
        end
      end
    end
  end
  return math.max(1, total)
end

function M.start(task)
  local c = companion.require_companion()
  local anchor = (task.center and type(task.center.x) == "number") and task.center or c.position
  task.radius = math.max(5, math.min(tonumber(task.radius) or DEFAULT_RADIUS, MAX_RADIUS))
  task.top_up_count = math.max(1, math.min(math.floor(tonumber(task.top_up_count) or TOP_UP_COUNT), 1000))
  task.max_empty_scans = task.max_empty_scans and math.max(1, math.floor(tonumber(task.max_empty_scans))) or nil
  if task.fuel and not prototypes.item[task.fuel] then
    error("no item called '" .. task.fuel .. "'")
  end
  task._rf = {
    anchor = { x = anchor.x, y = anchor.y },
    next_scan = 0,
    warned_empty = false,
    topped_up = 0,
    empty_scans = 0,
    unserviceable = {},
    serviced_this_round = {},
  }
end

function M.tick(task)
  local c = companion.get()
  if not c then
    return { status = "failed", detail = "the companion character is gone" }
  end
  local rf = task._rf

  -- If no stored fuel existed, finish a real timed coal-mining subtask before
  -- returning to the machine that requested service.
  if rf.fuel_mine then
    local result = mine.tick(rf.fuel_mine)
    if not result then return nil end
    if result.status ~= "done" then
      local id = rf.target and rf.target.valid and rf.target.unit_number
      if id then rf.unserviceable[id] = game.tick + 3600 end
      rf.target, rf.supply, rf.fuel_mine = nil, nil, nil
      task._approach = nil
      return nil
    end
    rf.fuel_mine = nil
    task._approach = nil
  end

  -- Serve the current customer.
  local target = rf.target
  if target and target.valid then
    local target_id = target.unit_number
    local fuel_left = burner_fuel_count(target)
    if fuel_left == nil or not needs_fuel(target, task) then
      if target_id then rf.serviced_this_round[target_id] = true end
      rf.target = nil
      rf.supply = nil
      task._approach = nil
      return nil
    end

    local fuel = pick_carried_fuel(c, target.burner, task.fuel)
    if not fuel then
      local supply = rf.supply
      if not (supply and supply.box and supply.box.valid) then
        -- Look around the machine being serviced.  Using the original command
        -- position here made fuel boxes near a distant machine invisible.
        local box, item = find_fuel_chest(c, target.burner, task.fuel,
          target.position, FUEL_CHEST_RADIUS)
        if box then
          supply = { box = box, item = item }
          rf.supply = supply
          task._approach = nil
        end
      end
      if not supply then
        local can_mine_coal = prototypes.entity["coal"]
          and compatible_fuel("coal", target.burner, task.fuel)
        if can_mine_coal then
          local child = {
            id = task.id,
            resource = "coal",
            count = desired_fuel_count(task, target, "coal"),
          }
          local ok = pcall(mine.start, child)
          if ok then
            rf.fuel_mine = child
            return nil
          end
        end
        if not rf.warned_empty then
          rf.warned_empty = true
          local text = "没有可用燃料，也没有找到可开采的兼容煤矿。"
          pcall(chat.say, { text = text })
          pcall(events.push, "supply_warning", text)
        end
        if target.unit_number then rf.unserviceable[target.unit_number] = game.tick + 3600 end
        if target_id then rf.serviced_this_round[target_id] = true end
        rf.target = nil
        return nil
      end

      local reached_supply = approach.ensure(task, c, supply.box.position, c.reach_distance)
      if type(reached_supply) == "table" then
        rf.supply = nil
        task._approach = nil
        return nil
      end
      if reached_supply ~= "ok" then return nil end
      local inv = supply.box.get_inventory(defines.inventory.chest)
      local available = inv and inv.get_item_count(supply.item) or 0
      -- Collect for all compatible low-fuel machines in one trip instead of
      -- returning to the same chest after every individual machine.
      local needed = math.max(
        math.max(0, desired_fuel_count(task, target, supply.item) - fuel_left),
        batch_fuel_need(c, task, supply.item))
      local n = math.min(available, needed)
      local inserted = 0
      if n > 0 then inserted = c.get_main_inventory().insert({ name = supply.item, count = n }) end
      if inserted > 0 then inv.remove({ name = supply.item, count = inserted }) end
      rf.supply = nil
      task._approach = nil
      return nil
    end

    local reached = approach.ensure(task, c, target.position, c.reach_distance)
    if type(reached) == "table" then
      -- Can't get there; skip it this round rather than killing the caretaker.
      if target_id then rf.serviced_this_round[target_id] = true end
      rf.target = nil
      task._approach = nil
      return nil
    end
    if reached ~= "ok" then return nil end

    rf.warned_empty = false
    local needed = math.max(0, desired_fuel_count(task, target, fuel) - fuel_left)
    local n = math.min(c.get_item_count(fuel), needed)
    local inserted = 0
    pcall(function() inserted = target.burner.inventory.insert({ name = fuel, count = n }) end)
    if inserted > 0 then
      c.remove_item({ name = fuel, count = inserted })
      rf.topped_up = rf.topped_up + 1
    end
    if target_id then rf.serviced_this_round[target_id] = true end
    rf.target = nil
    rf.supply = nil
    task._approach = nil
    return nil
  end
  rf.target = nil
  rf.supply = nil

  -- Look for the next machine running low.
  if game.tick < rf.next_scan then
    c.walking_state = { walking = false }
    return nil
  end
  rf.next_scan = game.tick + SCAN_INTERVAL_TICKS

  local best, best_d, best_power
  for _, e in ipairs(c.surface.find_entities_filtered({
    -- Search from the helper's current position so the caretaker can keep
    -- discovering new machines as it travels through the factory.
    position = rf.anchor,
    radius = task.radius,
    force = c.force,
  })) do
    if e.valid and e.type ~= "character" then
      local fuel_left = burner_fuel_count(e)
      local blocked_until = e.unit_number and rf.unserviceable[e.unit_number]
      local serviced = e.unit_number and rf.serviced_this_round[e.unit_number]
      if fuel_left ~= nil and needs_fuel(e, task)
        and not serviced and (not blocked_until or game.tick >= blocked_until) then
        local d = dist_sq(e.position, c.position)
        local power = is_power_device(e)
        if not best or (power and not best_power) or (power == best_power and d < best_d) then
          best, best_d, best_power = e, d, power
        end
      end
    end
  end
  rf.target = best
  if best then
    rf.empty_scans = 0
  elseif task.max_empty_scans then
    rf.empty_scans = rf.empty_scans + 1
    if rf.empty_scans >= task.max_empty_scans then
      return { status = "done", detail = "当前没有需要补充燃料的设备" }
    end
  elseif next(rf.serviced_this_round) then
    -- A completed round gets a pause before machines become eligible again.
    -- This prevents a partially filled priority generator monopolising a helper.
    rf.serviced_this_round = {}
    rf.next_scan = game.tick + ROUND_RESTART_TICKS
  end
  return nil -- persistent: only cancel/replace ends this task
end

-- Cheap pre-check used by autonomous scheduling so an idle helper does not
-- enter a persistent refuel task when there is no refuelling work at all.
function M.has_work(c, radius, desired_count, center)
  radius = math.max(5, math.min(tonumber(radius) or DEFAULT_RADIUS, MAX_RADIUS))
  desired_count = math.max(1, math.min(math.floor(tonumber(desired_count) or TOP_UP_COUNT), 1000))
  local probe = { top_up_count = desired_count }
  for _, e in ipairs(c.surface.find_entities_filtered({
    position = center or c.position,
    radius = radius,
    force = c.force,
  })) do
    if e.valid and e.type ~= "character" then
      if needs_fuel(e, probe) then return true end
    end
  end
  return false
end

return M
