-- Persistent physical production loop: mine raw material, feed a machine,
-- wait for its product, take the product, and store it in a mapped chest.
local companion = require("scripts.companion")
local mine = require("scripts.actions.mine")
local transfer = require("scripts.actions.transfer")
local approach = require("scripts.actions.approach")

local M = {}

local function mine_child(task)
  local child = { id = task.id, resource = task.resource, count = task.harvest_count }
  mine.start(child)
  task._chain.phase, task._chain.child = "mine", child
end

local function transfer_child(task, kind, target, item, count)
  local child = { id = task.id, target = { x = target.x, y = target.y }, items = { [item] = count } }
  transfer[kind].start(child)
  task._chain.phase, task._chain.child = kind, child
end

function M.start(task)
  companion.require_companion()
  task.harvest_count = math.max(1, math.min(math.floor(tonumber(task.harvest_count) or 50), 200))
  task.supply_count = math.max(1, math.min(math.floor(tonumber(task.supply_count) or 50), 1000))
  task.collect_count = math.max(1, math.min(math.floor(tonumber(task.collect_count) or task.supply_count), 1000))
  task._chain = { cycles = 0, next_check = 0, phase = "prepare" }
end

local function carry_inventory(c, inv)
  if not inv then return true end
  for _, stack in ipairs(inv.get_contents()) do
    local moved = c.get_main_inventory().insert({ name = stack.name, count = stack.count })
    if moved > 0 then inv.remove({ name = stack.name, count = moved }) end
    if moved < stack.count then return false end
  end
  return true
end

function M.tick(task)
  local c = companion.get()
  if not c then return { status = "failed", detail = "助手已不存在" } end
  local ch = task._chain
  if ch.phase == "prepare" then
    local source = task.source_entity
    if not (source and source.valid) then return { status = "failed", detail = "生产设备已不存在" } end
    local reached = approach.ensure(task, c, source.position, c.reach_distance)
    if type(reached) == "table" then return reached end
    if reached ~= "ok" then return nil end
    local input, output
    pcall(function() input = source.get_input_inventory() end)
    pcall(function() output = source.get_output_inventory() end)
    if not carry_inventory(c, output) or not carry_inventory(c, input) then
      return { status = "failed", detail = "助手背包空间不足，无法先取走设备内已有物品" }
    end
    task._approach = nil
    mine_child(task)
    return nil
  elseif ch.phase == "mine" then
    local result = mine.tick(ch.child)
    if not result then return nil end
    if result.status ~= "done" then return result end
    transfer_child(task, "insert", task.machine, task.raw_item, task.supply_count)
    return nil
  elseif ch.phase == "insert" then
    local result = transfer.insert.tick(ch.child)
    if not result then return nil end
    if result.status ~= "done" then return result end
    ch.phase, ch.child, ch.next_check = "wait", nil, game.tick + 60
    return nil
  elseif ch.phase == "wait" then
    if game.tick < ch.next_check then c.walking_state = { walking = false }; return nil end
    ch.next_check = game.tick + 60
    local source = task.source_entity
    if not (source and source.valid) then return { status = "failed", detail = "生产设备已不存在" } end
    local inv
    pcall(function() inv = source.get_output_inventory() end)
    if not inv or inv.get_item_count(task.output_item) == 0 then return nil end
    local n = math.min(inv.get_item_count(task.output_item), task.collect_count)
    transfer_child(task, "extract", task.machine, task.output_item, n)
    return nil
  elseif ch.phase == "extract" then
    local result = transfer.extract.tick(ch.child)
    if not result then return nil end
    if result.status ~= "done" then return result end
    transfer_child(task, "insert", task.destination, task.output_item, task.collect_count)
    ch.phase = "store"
    return nil
  end

  local result = transfer.insert.tick(ch.child)
  if not result then return nil end
  if result.status ~= "done" then return result end
  ch.cycles = ch.cycles + 1
  mine_child(task)
  return nil
end

return M
