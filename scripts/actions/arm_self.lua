-- Autonomous readiness job: walk to a friendly chest containing a compatible
-- gun/ammunition pair, take real items, and equip them.
local companion = require("scripts.companion")
local equipment = require("scripts.equipment")
local approach = require("scripts.actions.approach")

local M = {}

function M.find_task(c, radius)
  local armed = equipment.auto_arm(c)
  equipment.auto_equip_armor(c)
  if not armed then
    local box = equipment.find_armament_chest(c, radius or 256)
    if box then return { type = "arm_self", supply = box, supply_kind = "weapon" } end
  end
  local armor_box = equipment.find_armor_chest(c, radius or 256)
  return armor_box and { type = "arm_self", supply = armor_box, supply_kind = "armor" } or nil
end

function M.start(task)
  local c = companion.require_companion()
  if task.supply_kind == "armor" then
    if equipment.auto_equip_armor(c) then task._already_ready = true; return end
  elseif equipment.auto_arm(c) then
    task._already_ready = true
    return
  end
  if not (task.supply and task.supply.valid) then error("装备补给箱已不存在") end
end

function M.tick(task)
  local c = companion.get()
  if not c then return { status = "failed", detail = "助手已不存在" } end
  local ready
  if task.supply_kind == "armor" then
    ready = equipment.auto_equip_armor(c)
  else
    ready = equipment.auto_arm(c)
  end
  if task._already_ready or ready then
    return { status = "done", detail = task.supply_kind == "armor" and "已穿上护甲" or "已装备可用武器和弹药" }
  end
  local box = task.supply
  if not (box and box.valid) then return { status = "failed", detail = "装备补给箱已不存在" } end
  local reached = approach.ensure(task, c, box.position, c.reach_distance)
  if type(reached) == "table" then return reached end
  if reached ~= "ok" then return nil end
  local equipped
  if task.supply_kind == "armor" then
    equipped = equipment.take_armor_from_chest(c, box)
  else
    equipped = equipment.take_armament_from_chest(c, box)
  end
  return equipped
    and { status = "done", detail = task.supply_kind == "armor"
      and "已从己方箱子取得并穿上护甲" or "已从己方箱子取得并装备武器弹药" }
    or { status = "failed", detail = "补给箱中已没有可用的对应装备" }
end

return M
