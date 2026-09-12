-- Small autonomous jobs for companions with no player-assigned work.
-- Jobs are deliberately short so explicit commands take over naturally.
local companion = require("scripts.companion")
local tasks = require("scripts.tasks")
local equipment = require("scripts.equipment")
local refuel = require("scripts.actions.refuel")
local repair = require("scripts.actions.repair")

local M = {}
local ENEMY_TYPES = { "unit", "unit-spawner", "turret" }

local function random_minable(c)
  local list = {}
  for _, e in ipairs(c.surface.find_entities_filtered({
    position = c.position,
    radius = 20,
    type = { "resource", "tree", "simple-entity" },
  })) do
    if e.valid and e.prototype.mineable_properties.minable then list[#list + 1] = e end
  end
  if #list == 0 then return nil end
  return list[math.random(1, #list)]
end

local function nearby_enemy(c)
  return c.surface.find_entities_filtered({
    position = c.position,
    radius = 30,
    force = game.forces.enemy,
    type = ENEMY_TYPES,
    limit = 1,
  })[1]
end

local function wander_task(c)
  local angle = math.random() * math.pi * 2
  local distance = math.random(8, 20)
  local desired = {
    x = c.position.x + math.cos(angle) * distance,
    y = c.position.y + math.sin(angle) * distance,
  }
  local target = c.surface.find_non_colliding_position("character", desired, 10, 0.5)
  if not target then return nil end
  return { type = "walk_to", target = { x = target.x, y = target.y }, arrive_within = 1.5 }
end

function M.update()
  local assigned = { repair = 0, refuel = 0, mine = 0, patrol = 0 }
  -- Include autonomous work that is already running when enforcing the
  -- two-helper limit.
  for _, name in ipairs(companion.names()) do
    local active = tasks.active_summary(name)
    if active then
      if active.type == "keep_repaired" then assigned.repair = assigned.repair + 1
      elseif active.type == "keep_fueled" then assigned.refuel = assigned.refuel + 1
      elseif active.type == "mine" then assigned.mine = assigned.mine + 1
      elseif active.type == "patrol" then assigned.patrol = assigned.patrol + 1 end
    end
  end

  for _, name in ipairs(companion.names()) do
    if tasks.is_idle(name) then
      companion.set_context(name)
      local c = companion.get(name)
      if c then
        local task
        local enemy = nearby_enemy(c)
        if enemy and equipment.auto_arm(c) then
          task = { type = "fight", target = { x = c.position.x, y = c.position.y }, radius = 30 }
        elseif assigned.repair < 2 and repair.has_work(c, 256) then
          task = { type = "keep_repaired", radius = 256, max_empty_scans = 1 }
          assigned.repair = assigned.repair + 1
        elseif assigned.refuel < 2 and refuel.has_work(c, 256, storage.autonomy_fuel_target or 10) then
          task = {
            type = "keep_fueled", radius = 256,
            top_up_count = storage.autonomy_fuel_target or 10,
            max_empty_scans = 1,
          }
          assigned.refuel = assigned.refuel + 1
        elseif assigned.mine < 2 then
          local target = random_minable(c)
          if target then
            if target.type == "resource" then
              task = { type = "mine", resource = target.name, count = 20 }
            else
              task = { type = "mine", target = { x = target.position.x, y = target.position.y } }
            end
            assigned.mine = assigned.mine + 1
          end
        end
        if not task and assigned.patrol < 2 then
          task = { type = "patrol", radius = 12, rounds = 1 }
          assigned.patrol = assigned.patrol + 1
        end
        task = task or wander_task(c)
        if task then
          tasks.enqueue({ task = task, replace = false, background = true, quiet = true })
        end
      end
    end
  end
  companion.set_context(nil)
end

return M
