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

local function nearest_enemy(surface, position, radius)
  local best, best_d
  for _, enemy in ipairs(surface.find_entities_filtered({
    position = position,
    radius = radius,
    force = game.forces.enemy,
    type = ENEMY_TYPES,
  })) do
    if enemy.valid then
      local d = dist_sq(position, enemy.position)
      if not best or d < best_d then best, best_d = enemy, d end
    end
  end
  return best
end

-- Operate the real weapon and ammunition inventory of the player's vehicle.
-- Prefer its currently selected loaded weapon, otherwise select another
-- loaded slot. Factorio performs the shot and consumes vehicle ammunition.
local function shoot_vehicle_weapon(vehicle)
  if not (vehicle and vehicle.valid) then return false end
  local ammo_inv
  local ok = pcall(function() ammo_inv = vehicle.get_inventory(defines.inventory.car_ammo) end)
  if not ok or not ammo_inv or #ammo_inv == 0 then return false end

  local selected
  pcall(function() selected = vehicle.selected_gun_index end)
  if type(selected) ~= "number" or selected < 1 or selected > #ammo_inv
      or not ammo_inv[selected].valid_for_read then
    selected = nil
    for i = 1, #ammo_inv do
      if ammo_inv[i].valid_for_read then selected = i; break end
    end
  end
  if not selected then return false end

  local range = 25
  pcall(function()
    local gun = vehicle.prototype.guns[selected]
    if gun and gun.attack_parameters and gun.attack_parameters.range then
      range = gun.attack_parameters.range
    end
  end)
  local enemy = nearest_enemy(vehicle.surface, vehicle.position, range)
  if not enemy then return false end

  local fired = pcall(function()
    vehicle.selected_gun_index = selected
    vehicle.shooting_state = {
      state = defines.shooting.shooting_enemies,
      position = { x = enemy.position.x, y = enemy.position.y },
    }
  end)
  return fired
end

local function passenger_is(vehicle, occupant)
  local passenger
  pcall(function() passenger = vehicle.get_passenger() end)
  return passenger == occupant
end

local function try_board_player_vehicle(c, p, f)
  local vehicle = p.vehicle
  if not (vehicle and vehicle.valid) then return false end
  local passenger
  local supported = pcall(function() passenger = vehicle.get_passenger() end)
  if not supported or (passenger and passenger ~= c) then return false end
  if passenger == c then return true end
  if dist_sq(c.position, vehicle.position) > (c.reach_distance + 1) ^ 2 then return false end
  local boarded = pcall(function() vehicle.set_passenger(c) end)
  if boarded and c.vehicle == vehicle then
    f.walk, f.walk_target, f.retry_at = nil, nil, nil
    c.walking_state = { walking = false }
    return true
  end
  return false
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

  -- A follower uses only the passenger seat and never takes control from the
  -- player. When the player exits or changes vehicles, leave immediately and
  -- resume the same persistent follow task on foot.
  if c.vehicle then
    if p.vehicle == c.vehicle and passenger_is(c.vehicle, c) then
      if not shoot_vehicle_weapon(c.vehicle) and not shoot_nearby_enemy(c) then
        pcall(function() c.shooting_state = { state = defines.shooting.not_shooting } end)
      end
      return nil
    end
    pcall(function() c.driving = false end)
    f.walk, f.walk_target, f.retry_at = nil, nil, nil
  end

  if p.vehicle and try_board_player_vehicle(c, p, f) then
    if not shoot_vehicle_weapon(c.vehicle) and not shoot_nearby_enemy(c) then
      pcall(function() c.shooting_state = { state = defines.shooting.not_shooting } end)
    end
    return nil
  end

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

-- Called when follow is replaced/cancelled so a seated helper cannot remain
-- trapped in the old vehicle while its next task tries to walk elsewhere.
function M.stop()
  local c = companion.get()
  if c and c.vehicle and passenger_is(c.vehicle, c) then
    pcall(function() c.driving = false end)
  end
end

return M
