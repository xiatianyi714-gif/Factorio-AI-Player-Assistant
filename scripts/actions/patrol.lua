local companion = require("scripts.companion")
local equipment = require("scripts.equipment")
local walk = require("scripts.actions.walk")
local approach = require("scripts.actions.approach")

local M = {}
local ENEMY_TYPES = { "unit", "unit-spawner", "turret" }
local DETECTION_RADIUS = 30

local function stop_shooting(c)
  pcall(function() c.shooting_state = { state = defines.shooting.not_shooting } end)
end

local function dist_sq(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

local function nearest_enemy(c)
  local best, best_d
  for _, e in ipairs(c.surface.find_entities_filtered({
    position = c.position, radius = DETECTION_RADIUS, force = game.forces.enemy, type = ENEMY_TYPES,
  })) do
    local d = dist_sq(e.position, c.position)
    if e.valid and (not best or d < best_d) then best, best_d = e, d end
  end
  return best
end

local function gun_range(c)
  local gun = equipment.current_gun(c)
  local range = 15
  if gun then
    pcall(function()
      local ap = prototypes.item[gun].attack_parameters
      if ap and ap.range then range = ap.range end
    end)
  end
  return range
end

local function safe_point(c, desired)
  -- Route clicks may land at the centre of a turret or another building.
  -- Never preserve an occupied coordinate: resolve it to the nearest place a
  -- character can actually stand, with a wider second attempt for large sites.
  return c.surface.find_non_colliding_position("character", desired, 16, 0.25)
    or c.surface.find_non_colliding_position("character", desired, 32, 0.5)
    or { x = c.position.x, y = c.position.y }
end

function M.start(task)
  local c = companion.require_companion()
  equipment.auto_arm(c) -- Being unarmed no longer prevents patrol movement.
  local points = {}
  if type(task.points) == "table" and #task.points >= 2 then
    for _, point in ipairs(task.points) do
      if type(point) ~= "table" or type(point.x) ~= "number" or type(point.y) ~= "number" then
        error("自定义巡逻点必须包含有效坐标")
      end
      points[#points + 1] = safe_point(c, { x = point.x, y = point.y })
    end
  else
    local r = math.max(6, math.min(tonumber(task.radius) or 12, 40))
    local names, index = companion.names(), 1
    for i, name in ipairs(names) do if name == companion.context() then index = i break end end
    local phase = (index - 1) * math.pi / 2
    local x, y = c.position.x, c.position.y
    for i = 0, 3 do
      local angle = phase + i * math.pi / 2
      points[#points + 1] = safe_point(c, { x = x + math.cos(angle) * r, y = y + math.sin(angle) * r })
    end
  end
  task._patrol = { points = points, index = 1, walk = {}, legs = 0 }
  walk.begin(task._patrol.walk, c, points[1], 1.5, true)
end

function M.tick(task)
  local c = companion.get()
  if not c then return { status = "failed", detail = "助手已不存在" } end
  local p = task._patrol
  if task._resume_after_combat then
    task._resume_after_combat = nil
    p.enemy, p.combat_walk, p.arm_supply = nil, nil, nil
    p.walk = {}
    walk.begin(p.walk, c, p.points[p.index], 1.5, true)
  end
  local armed = equipment.auto_arm(c)

  -- Patrols remain useful when supplies exist elsewhere in the base: walk to
  -- a friendly chest, take a real compatible gun/ammo pair, then resume the
  -- exact route leg that was interrupted.
  if not armed then
    if not p.arm_retry_tick or game.tick >= p.arm_retry_tick then
      if not (p.arm_supply and p.arm_supply.valid) then
        p.arm_supply = equipment.find_armament_chest(c, 256)
        task._approach = nil
      end
      if p.arm_supply then
        local reached = approach.ensure(task, c, p.arm_supply.position, c.reach_distance)
        if type(reached) == "table" then
          p.arm_supply = nil
          p.arm_retry_tick = game.tick + 300
          task._approach = nil
        elseif reached == "ok" then
          if equipment.take_armament_from_chest(c, p.arm_supply) then
            p.resume_route_after_supply = true
          end
          p.arm_supply = nil
          p.arm_retry_tick = game.tick + 300
          task._approach = nil
        end
        return nil
      end
      p.arm_retry_tick = game.tick + 300
    end
  else
    p.arm_supply = nil
    task._approach = nil
    if p.resume_route_after_supply then
      p.resume_route_after_supply = nil
      p.walk = {}
      walk.begin(p.walk, c, p.points[p.index], 1.5, true)
    end
  end

  local enemy = p.enemy
  if not (enemy and enemy.valid) then
    p.enemy = nil
    p.combat_walk = nil
    enemy = nearest_enemy(c)
    p.enemy = enemy
  end

  if enemy and armed then
    p.was_fighting = true
    local range = gun_range(c)
    local distance = math.sqrt(dist_sq(c.position, enemy.position))
    if distance > range - 1 then
      stop_shooting(c)
      if not p.combat_walk or not p.combat_goal
        or dist_sq(p.combat_goal, enemy.position) > 9 then
        p.combat_walk = {}
        p.combat_goal = { x = enemy.position.x, y = enemy.position.y }
        walk.begin(p.combat_walk, c, p.combat_goal, math.max(range - 2, 2))
      end
      local result = walk.step(p.combat_walk, c, task.id)
      if result == "arrived" then
        p.combat_walk = nil
      elseif type(result) == "table" then
        p.enemy, p.combat_walk = nil, nil
      end
      return nil
    end
    c.walking_state = { walking = false }
    c.shooting_state = {
      state = defines.shooting.shooting_enemies,
      position = { x = enemy.position.x, y = enemy.position.y },
    }
    return nil
  end

  stop_shooting(c)
  if p.was_fighting then
    -- Combat movement invalidates the old route leg. Resume the same numbered
    -- patrol point with a fresh path; never advance merely because combat ended.
    p.was_fighting = nil
    p.combat_goal = nil
    p.walk = {}
    walk.begin(p.walk, c, p.points[p.index], 1.5, true)
  end

  local result = walk.step(p.walk, c, task.id)
  if result == "arrived" then
    p.legs = p.legs + 1
    if task.rounds and p.legs >= math.max(1, math.floor(task.rounds)) * #p.points then
      c.walking_state = { walking = false }
      return { status = "done", detail = "完成一轮空闲巡逻" }
    end
    p.index = p.index % #p.points + 1
    p.walk = {}
    walk.begin(p.walk, c, p.points[p.index], 1.5, true)
  elseif type(result) == "table" then
    -- A blocked/stale path is not an arrival. Retry this exact route point so
    -- custom patrols always remain 1 -> 2 -> 3 -> ... in the saved order.
    p.walk = {}
    walk.begin(p.walk, c, p.points[p.index], 1.5, true)
  end
  return nil
end

return M
