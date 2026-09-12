-- Physical worker for GUI box selections. The companion walks into normal
-- reach before reviving a ghost or mining an entity; no remote instant work.
local companion = require("scripts.companion")
local approach = require("scripts.actions.approach")

local M = {}

local function original_mining_ticks(c, e)
  local mining_time = e.prototype.mineable_properties.mining_time or 1
  local base_speed = c.prototype.mining_speed or 1
  local personal_bonus = tonumber(c.character_mining_speed_modifier) or 0
  local force_bonus = tonumber(c.force.manual_mining_speed_modifier) or 0
  local speed = base_speed * math.max(0.01, 1 + personal_bonus + force_bonus)
  return math.max(1, math.ceil(mining_time * 60 / speed))
end

local function placement_item(ghost)
  local products = ghost.ghost_prototype.items_to_place_this
  return products and products[1] and products[1].name or nil
end

local function take_from_reachable_chest(c, item_name)
  local types = { "container", "logistic-container" }
  for _, box in ipairs(c.surface.find_entities_filtered({
    position = c.position,
    radius = c.reach_distance,
    force = c.force,
    type = types,
  })) do
    local inv = box.get_inventory(defines.inventory.chest)
    if inv and inv.get_item_count(item_name) > 0 then
      local moved = c.get_main_inventory().insert({ name = item_name, count = 1 })
      if moved > 0 then
        inv.remove({ name = item_name, count = moved })
        return true
      end
    end
  end
  return false
end

local function next_entity(task)
  while task._index <= #task.entities do
    local e = task.entities[task._index]
    if e and e.valid then return e end
    task._index = task._index + 1
    task._skipped = task._skipped + 1
  end
  return nil
end

local function advance(task)
  task._index = task._index + 1
  task._approach = nil
  task._mine_ticks = nil
end

function M.start(task)
  companion.require_companion()
  if task.mode ~= "build" and task.mode ~= "demolish" then error("invalid local selection mode") end
  if type(task.entities) ~= "table" or #task.entities == 0 then error("selection contains no targets") end
  task._index, task._done, task._skipped = 1, 0, 0
end

function M.tick(task)
  local c = companion.get()
  if not c then return { status = "failed", detail = "the companion character is gone" } end
  local e = next_entity(task)
  if not e then
    c.mining_state = { mining = false }
    return {
      status = task._done > 0 and "done" or "failed",
      detail = string.format("completed %d target(s), skipped %d", task._done, task._skipped),
    }
  end

  local reach = task.mode == "build" and c.build_distance or c.resource_reach_distance
  local reached = approach.ensure(task, c, e.position, reach)
  if type(reached) == "table" then
    task._skipped = task._skipped + 1
    advance(task)
    return nil
  end
  if reached ~= "ok" then return nil end

  if task.mode == "build" then
    if e.type ~= "entity-ghost" then
      task._skipped = task._skipped + 1
      advance(task)
      return nil
    end
    local item = placement_item(e)
    if not item then
      task._skipped = task._skipped + 1
      advance(task)
      return nil
    end
    if c.get_item_count(item) == 0 then take_from_reachable_chest(c, item) end
    if c.get_item_count(item) == 0 then
      task._skipped = task._skipped + 1
      advance(task)
      return nil
    end
    c.remove_item({ name = item, count = 1 })
    local ok, revived = pcall(function() return e.revive({ raise_revive = true }) end)
    if ok and revived then
      task._done = task._done + 1
    else
      c.insert({ name = item, count = 1 })
      task._skipped = task._skipped + 1
    end
    advance(task)
    return nil
  end

  if e.type == "character" or not e.minable then
    task._skipped = task._skipped + 1
    advance(task)
    return nil
  end
  if not task._mine_ticks then
    task._mine_ticks = original_mining_ticks(c, e)
  end
  c.mining_state = { mining = true, position = e.position }
  pcall(c.update_selected_entity, e.position)
  task._mine_ticks = task._mine_ticks - 1
  if task._mine_ticks > 0 then return nil end
  c.mining_state = { mining = false }
  local ok, mined = pcall(function()
    return e.mine({ inventory = c.get_main_inventory(), force = true, raise_destroyed = true })
  end)
  if ok and mined then task._done = task._done + 1 else task._skipped = task._skipped + 1 end
  advance(task)
  return nil
end

return M
