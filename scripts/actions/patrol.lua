local companion = require("scripts.companion")
local equipment = require("scripts.equipment")
local walk = require("scripts.actions.walk")

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
  return c.surface.find_non_colliding_position("character", desired, 8, 0.5) or desired
end

function M.start(task)
  local c = companion.require_companion()
  equipment.auto_arm(c) -- Being unarmed no longer prevents patrol movement.
  local r = math.max(6, math.min(tonumber(task.radius) or 12, 40))
  local names, index = companion.names(), 1
  for i, name in ipairs(names) do if name == companion.context() then index = i break end end
  local phase = (index - 1) * math.pi / 2
  local x, y = c.position.x, c.position.y
  local points = {}
  for i = 0, 3 do
    local angle = phase + i * math.pi / 2
    points[#points + 1] = safe_point(c, { x = x + math.cos(angle) * r, y = y + math.sin(angle) * r })
  end
  task._patrol = { points = points, index = 1, walk = {}, legs = 0 }
  walk.begin(task._patrol.walk, c, points[1], 1.5)
end

function M.tick(task)
  local c = companion.get()
  if not c then return { status = "failed", detail = "助手已不存在" } end
  local p = task._patrol
  local armed = equipment.auto_arm(c)

  local enemy = p.enemy
  if not (enemy and enemy.valid) then
    p.enemy = nil
    p.combat_walk = nil
    enemy = nearest_enemy(c)
    p.enemy = enemy
  end

  if enemy and armed then
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
  local result = walk.step(p.walk, c, task.id)
  if result == "arrived" or type(result) == "table" then
    p.legs = p.legs + 1
    if task.rounds and p.legs >= math.max(1, math.floor(task.rounds)) * #p.points then
      c.walking_state = { walking = false }
      return { status = "done", detail = "完成一轮空闲巡逻" }
    end
    p.index = p.index % #p.points + 1
    p.walk = {}
    walk.begin(p.walk, c, p.points[p.index], 1.5)
  end
  return nil
end

return M
