-- Persistent mine-and-feed cycle.  The helper physically mines a configured
-- batch, walks to the chosen machine/container, inserts a configured amount,
-- then repeats until replaced or stopped.
local companion = require("scripts.companion")
local mine = require("scripts.actions.mine")
local transfer = require("scripts.actions.transfer")

local M = {}

local function new_mine(task)
  local child = {
    id = task.id,
    resource = task.resource,
    count = task.harvest_count,
  }
  mine.start(child)
  task._cycle = { phase = "mine", child = child, cycles = (task._cycle and task._cycle.cycles) or 0 }
end

function M.start(task)
  companion.require_companion()
  if type(task.resource) ~= "string" or type(task.product) ~= "string" then
    error("mine-and-supply needs a resource and its mined product")
  end
  if type(task.target) ~= "table" or type(task.target.x) ~= "number" or type(task.target.y) ~= "number" then
    error("mine-and-supply needs a production target")
  end
  task.harvest_count = math.max(1, math.min(math.floor(tonumber(task.harvest_count) or 50), 200))
  task.supply_count = math.max(1, math.min(math.floor(tonumber(task.supply_count) or 50), 1000))
  new_mine(task)
end

function M.tick(task)
  local c = companion.get()
  if not c then return { status = "failed", detail = "the companion character is gone" } end
  local cycle = task._cycle
  local result
  if cycle.phase == "mine" then
    result = mine.tick(cycle.child)
    if not result then return nil end
    if result.status ~= "done" then return result end
    local child = {
      id = task.id,
      target = { x = task.target.x, y = task.target.y },
      items = { [task.product] = task.supply_count },
    }
    transfer.insert.start(child)
    cycle.phase, cycle.child = "supply", child
    return nil
  end

  result = transfer.insert.tick(cycle.child)
  if not result then return nil end
  if result.status ~= "done" then return result end
  cycle.cycles = cycle.cycles + 1
  new_mine(task)
  return nil
end

return M
