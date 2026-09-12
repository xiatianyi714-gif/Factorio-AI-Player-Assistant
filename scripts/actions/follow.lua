-- follow_player: persistent task — runs until cancelled or replaced, never
-- returns done. Walks toward the player when too far, stands still when close.
local companion = require("scripts.companion")
local walk = require("scripts.actions.walk")
local equipment = require("scripts.equipment")

local M = {}

local SLACK = 2 -- start walking when further than distance + SLACK
local RETARGET_DIST_SQ = 25 -- re-path when the player moved >5 tiles from our goal
local RETRY_DELAY_TICKS = 60 -- pause after a failed walk attempt, then try again
local ENEMY_TYPES = { "unit", "unit-spawner", "turret" }

local function dist_sq(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

local function shoot_nearby_enemy(c)
  if not equipment.auto_arm(c) then return false end
  local gun = equipment.current_gun(c)
  local range = 15
  pcall(function()
    local ap = prototypes.item[gun].attack_parameters
    if ap and ap.range then range = ap.range end
  end)
  local best, best_d
  for _, enemy in ipairs(c.surface.find_entities_filtered({
    position = c.position,
    radius = range,
    force = game.forces.enemy,
    type = ENEMY_TYPES,
  })) do
    local d = dist_sq(c.position, enemy.position)
    if enemy.valid and (not best or d < best_d) then best, best_d = enemy, d end
  end
  if not best then return false end
  c.shooting_state = {
    state = defines.shooting.shooting_enemies,
    position = { x = best.position.x, y = best.position.y },
  }
  return true
end

function M.start(task)
  companion.require_companion()
  if task.player ~= nil and type(task.player) ~= "string" then
    error("follow_player: player must be a player name string")
  end
  task.distance = math.max(tonumber(task.distance) or 3, 1)
  task._follow = {}
end

function M.tick(task)
  local c = companion.get()
  if not c then
    return { status = "failed", detail = "the companion character is gone" }
  end

  local p
  if task.player then
    p = game.get_player(task.player)
    if not p or not p.connected then
      return { status = "failed", detail = "player " .. task.player .. " isn't online — can't follow them" }
    end
  else
    p = game.connected_players[1]
    if not p then
      return { status = "failed", detail = "no players are online to follow" }
    end
  end
  if p.surface ~= c.surface then
    return { status = "failed", detail = p.name .. " is on a different surface — I can't follow them there" }
  end

  local f = task._follow
  if not shoot_nearby_enemy(c) then
    pcall(function() c.shooting_state = { state = defines.shooting.not_shooting } end)
  end
  local ppos = p.position
  local near = task.distance + SLACK

  if dist_sq(c.position, ppos) <= near * near then
    f.walk = nil
    c.walking_state = { walking = false }
    return nil
  end

  if f.retry_at then
    if game.tick < f.retry_at then
      c.walking_state = { walking = false }
      return nil
    end
    f.retry_at = nil
  end

  if not f.walk or dist_sq(ppos, f.walk_target) > RETARGET_DIST_SQ then
    f.walk = {}
    f.walk_target = { x = ppos.x, y = ppos.y }
    walk.begin(f.walk, c, f.walk_target, task.distance)
  end

  local r = walk.step(f.walk, c, task.id)
  if r == "arrived" then
    f.walk = nil
  elseif type(r) == "table" then
    -- blocked for now — a persistent task waits and retries instead of failing
    f.walk = nil
    f.retry_at = game.tick + RETRY_DELAY_TICKS
  end
  return nil
end

return M
