-- Autonomous readiness job: walk to a friendly chest containing a compatible
-- gun/ammunition pair, take real items, and equip them.
local companion = require("scripts.companion")
local equipment = require("scripts.equipment")
local approach = require("scripts.actions.approach")

local M = {}

function M.find_task(c, radius)
  if equipment.auto_arm(c) then return nil end
  local box = equipment.find_armament_chest(c, radius or 256)
  return box and { type = "arm_self", supply = box } or nil
end

function M.start(task)
  local c = companion.require_companion()
  if equipment.auto_arm(c) then task._already_ready = true; return end
  if not (task.supply and task.supply.valid) then error("武器补给箱已不存在") end
end

function M.tick(task)
  local c = companion.get()
  if not c then return { status = "failed", detail = "助手已不存在" } end
  if task._already_ready or equipment.auto_arm(c) then
    return { status = "done", detail = "已装备可用武器和弹药" }
  end
  local box = task.supply
  if not (box and box.valid) then return { status = "failed", detail = "武器补给箱已不存在" } end
  local reached = approach.ensure(task, c, box.position, c.reach_distance)
  if type(reached) == "table" then return reached end
  if reached ~= "ok" then return nil end
  return equipment.take_armament_from_chest(c, box)
    and { status = "done", detail = "已从己方箱子取得并装备武器弹药" }
    or { status = "failed", detail = "补给箱中已没有可配套使用的枪和弹药" }
end

return M
