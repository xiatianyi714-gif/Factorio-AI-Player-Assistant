-- Move real materials from the helper/reachable chests into a selected
-- production entity. The target's own insert rules decide compatibility.
local companion = require("scripts.companion")
local approach = require("scripts.actions.approach")
local material_supply = require("scripts.actions.material_supply")
local reservations = require("scripts.reservations")
local machine_supply = require("scripts.machine_supply")

local M = {}

local function take_from_chests(c, name, wanted)
  local moved = 0
  for _, box in ipairs(c.surface.find_entities_filtered({
    position = c.position,
    radius = c.reach_distance,
    force = c.force,
    type = { "container", "logistic-container" },
  })) do
    if moved >= wanted then break end
    local inv = box.get_inventory(defines.inventory.chest)
    if inv then
      local available = inv.get_item_count(name)
      if available > 0 then
        local n = math.min(available, wanted - moved)
        local inserted = c.get_main_inventory().insert({ name = name, count = n })
        if inserted > 0 then
          inv.remove({ name = name, count = inserted })
          moved = moved + inserted
        end
      end
    end
  end
  return moved
end

function M.start(task)
  local c = companion.require_companion()
  if not prototypes.item[task.item] then error("unknown supply item: " .. tostring(task.item)) end
  if type(task.target) ~= "table" or type(task.target.x) ~= "number" or type(task.target.y) ~= "number" then
    error("production supply needs a target position")
  end
  task.count = math.max(1, math.floor(tonumber(task.count) or 1))
  local main = c.get_main_inventory()
  local missing = task.count - main.get_item_count(task.item)
  if missing > 0 then take_from_chests(c, task.item, missing) end
  if main.get_item_count(task.item) == 0 and not task.find_in_chests then
    error("助手背包和伸手可及的箱子里都没有 " .. task.item)
  end
end

function M.tick(task)
  local c = companion.get()
  if not c then return { status = "failed", detail = "the companion character is gone" } end
  local main = c.get_main_inventory()
  if main.get_item_count(task.item) == 0 and task.find_in_chests then
    local supplied = material_supply.ensure(task, c, task.item, task.count, task.target)
    if supplied == nil then return nil end
    if supplied == "missing" then
      return { status = "failed", detail = "附近己方箱子里没有可用的 " .. task.item }
    end
  end
  local reached = approach.ensure(task, c, task.target, c.reach_distance)
  if type(reached) == "table" then return reached end
  if reached ~= "ok" then return nil end
  local target = task.target_entity
  if not (target and target.valid) then target = approach.find_entity_near(c, task.target, 1.0) end
  if not target then return { status = "failed", detail = "指定的生产设备或容器已不存在" } end
  if machine_supply.supported(target) and not machine_supply.accepts_input(target, task.item) then
    return { status = "failed", detail = task.item .. " 不是该设备当前配方的原材料，已取消错误投料" }
  end
  if task.reservation_key and not reservations.claim_key(task.reservation_key, companion.context(), task.id) then
    return { status = "done", detail = "另一名助手已接手该生产设备" }
  end
  local available = math.min(task.count, main.get_item_count(task.item))
  local inserted = 0
  if available > 0 then
    pcall(function() inserted = target.insert({ name = task.item, count = available }) end)
  end
  if inserted <= 0 then
    return { status = "failed", detail = target.name .. " 不接受 " .. task.item .. "，或其库存已满" }
  end
  main.remove({ name = task.item, count = inserted })
  return {
    status = "done",
    detail = string.format("向 %s 投入了 %d 个 %s", target.name, inserted, task.item),
  }
end

return M
