-- Return to the companion's death location and recover only items recorded in
-- its death manifest. This avoids collecting unrelated player drops nearby.
local companion = require("scripts.companion")
local approach = require("scripts.actions.approach")

local M = {}
local SEARCH_RADIUS = 4
local RETRY_TICKS = 10 * 60

local function remaining(task)
  local n = 0
  for _, count in pairs(task.items or {}) do n = n + count end
  return n
end

local function transfer_inventory(task, c, inv)
  if not inv then return 0 end
  local moved_total = 0
  for _, stack in ipairs(inv.get_contents()) do
    local wanted = task._collect_all and stack.count or (task.items[stack.name] or 0)
    if wanted > 0 then
      local request = math.min(wanted, stack.count)
      local moved = c.get_main_inventory().insert({
        name = stack.name, count = request, quality = stack.quality,
      })
      if moved > 0 then
        inv.remove({ name = stack.name, count = moved, quality = stack.quality })
        if not task._collect_all then task.items[stack.name] = wanted - moved end
        moved_total = moved_total + moved
      end
    end
  end
  return moved_total
end

function M.start(task)
  companion.require_companion()
  if type(task.target) ~= "table" or type(task.target.x) ~= "number" or type(task.target.y) ~= "number" then
    error("death recovery requires a target position")
  end
  task.items = task.items or {}
  task._expected = remaining(task)
  task._recovered = 0
  task._collect_all = task._expected == 0
  task._retry_until = game.tick + RETRY_TICKS
end

function M.tick(task)
  local c = companion.get()
  if not c then return { status = "failed", detail = "助手已不存在" } end
  if task.surface_index and c.surface.index ~= task.surface_index then
    return { status = "failed", detail = "死亡物品位于其他星球或地表，无法自动步行取回" }
  end
  if not task._collect_all and remaining(task) <= 0 then
    return { status = "done", detail = string.format("已取回 %d 个死亡遗留物品", task._recovered) }
  end

  local reached = approach.ensure(task, c, task.target, c.reach_distance)
  if type(reached) == "table" then return reached end
  if reached ~= "ok" then return nil end

  for _, corpse in ipairs(c.surface.find_entities_filtered({
    position = task.target, radius = SEARCH_RADIUS, type = "character-corpse",
  })) do
    local inv
    pcall(function() inv = corpse.get_inventory(defines.inventory.character_corpse) end)
    task._recovered = task._recovered + transfer_inventory(task, c, inv)
  end

  for _, dropped in ipairs(c.surface.find_entities_filtered({
    position = task.target, radius = SEARCH_RADIUS, type = "item-entity",
  })) do
    if dropped.valid and dropped.stack and dropped.stack.valid_for_read then
      local stack = dropped.stack
      local wanted = task._collect_all and stack.count or (task.items[stack.name] or 0)
      if wanted > 0 then
        local request = math.min(wanted, stack.count)
        local moved = c.get_main_inventory().insert({
          name = stack.name, count = request, quality = stack.quality,
        })
        if moved > 0 then
          if not task._collect_all then task.items[stack.name] = wanted - moved end
          task._recovered = task._recovered + moved
          if moved >= stack.count then dropped.destroy() else stack.count = stack.count - moved end
        end
      end
    end
  end

  if task._collect_all then
    if task._recovered > 0 then
      return { status = "done", detail = string.format("已从死亡点取回 %d 个物品", task._recovered) }
    end
    if game.tick < task._retry_until then return nil end
    return { status = "done", detail = "死亡点没有可取回的物品" }
  end

  local left = remaining(task)
  if left > 0 then
    if game.tick < task._retry_until then return nil end
    return {
      status = task._recovered > 0 and "done" or "failed",
      detail = string.format("已取回 %d/%d 个死亡遗留物品；其余 %d 个可能已被取走或背包空间不足",
        task._recovered, task._expected, left),
    }
  end
  return { status = "done", detail = string.format("已取回全部 %d 个死亡遗留物品", task._recovered) }
end

return M
