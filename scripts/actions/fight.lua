-- fight: anchored area combat. Walks into gun range, re-sets shooting_state
-- every tick (one-shot writes, like walking_state), moves to the next enemy
-- until the radius is clear, retreats toward a player at low health.
local companion = require("scripts.companion")
local equipment = require("scripts.equipment")
local walk = require("scripts.actions.walk")

local M = {}

local ENEMY_TYPES = { "unit", "unit-spawner", "turret" }
local DEFAULT_RADIUS = 20
local MAX_RADIUS = 40
local DEFAULT_FLEE_BELOW = 0.3
local MELEE_RANGE = 1.75
local MELEE_DAMAGE = 8
local MELEE_COOLDOWN = 30

local function stop_shooting(c)
  pcall(function()
    c.shooting_state = { state = defines.shooting.not_shooting }
  end)
end

local function gun_range(c)
  local range = 15
  local name = equipment.current_gun(c)
  if name then
    pcall(function()
      local ap = prototypes.item[name].attack_parameters
      if ap and type(ap.range) == "number" then range = ap.range end
    end)
  end
  return range
end

local function total_ammo(c)
  local n = 0
  pcall(function()
    local inv = c.get_inventory(defines.inventory.character_ammo)
    if inv then
      for i = 1, #inv do
        if inv[i].valid_for_read then n = n + inv[i].count end
      end
    end
  end)
  return n
end

local function kills_phrase(n)
  return string.format("%d kill%s", n, n == 1 and "" or "s")
end

function M.start(task)
  local c = companion.require_companion()
  equipment.auto_arm(c)
  task.radius = math.min(tonumber(task.radius) or DEFAULT_RADIUS, MAX_RADIUS)
  task.flee_below = tonumber(task.flee_below) or DEFAULT_FLEE_BELOW
  local anchor = (task.target and type(task.target.x) == "number") and task.target or c.position
  task._fight = {
    anchor = { x = anchor.x, y = anchor.y },
    kills = 0,
    range = gun_range(c),
    engaged = false,
    next_melee_tick = 0,
  }
end

local function pick_target(c, f, radius)
  local best, best_d
  for _, e in ipairs(c.surface.find_entities_filtered({
    type = ENEMY_TYPES,
    force = game.forces.enemy,
    position = f.anchor,
    radius = radius,
  })) do
    if e.valid then
      local dx, dy = e.position.x - c.position.x, e.position.y - c.position.y
      local d = dx * dx + dy * dy
      if not best or d < best_d then
        best, best_d = e, d
      end
    end
  end
  return best
end

local function health_ratio(e)
  local max = 250
  pcall(function() max = e.max_health end)
  return math.max(0, math.min(1, (e.health or 0) / math.max(max or 250, 1)))
end

-- Estimate the local balance without granting either side hidden bonuses.
-- Healthy nearby characters and defensive turrets count as support; guns and
-- ammunition make the companion itself substantially more confident.
local function tactical_balance(c)
  local enemies = c.surface.find_entities_filtered({
    position = c.position, radius = 22, force = game.forces.enemy,
    type = ENEMY_TYPES,
  })
  local threat = 0
  local ex, ey = 0, 0
  for _, e in ipairs(enemies) do
    if e.valid then
      local weight = e.type == "turret" and 2 or (e.type == "unit-spawner" and 1.5 or 1)
      threat = threat + weight
      ex, ey = ex + e.position.x, ey + e.position.y
    end
  end

  local gun = equipment.current_gun(c)
  local armed = gun ~= nil and total_ammo(c) > 0
  local support = (armed and 2.5 or 1.2) * health_ratio(c)
  local friends = c.surface.find_entities_filtered({
    position = c.position, radius = 22, force = c.force,
    type = { "character", "ammo-turret", "electric-turret", "fluid-turret", "combat-robot" },
  })
  for _, ally in ipairs(friends) do
    if ally.valid and ally ~= c then
      local weight = ally.type == "character" and 1 or 1.5
      support = support + weight * health_ratio(ally)
    end
  end
  local center = #enemies > 0 and { x = ex / #enemies, y = ey / #enemies } or nil
  return threat, support, armed, center, #enemies, #friends - 1
end

local function retreat_destination(c, enemy_center)
  if enemy_center then
    local dx, dy = c.position.x - enemy_center.x, c.position.y - enemy_center.y
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 0.1 then dx, dy, length = 1, 0, 1 end
    local desired = { x = c.position.x + dx / length * 24, y = c.position.y + dy / length * 24 }
    local safe = c.surface.find_non_colliding_position("character", desired, 12, 0.5)
    if safe then return { x = safe.x, y = safe.y } end
  end
  local p = game.connected_players[1]
  if p and p.character then return { x = p.position.x, y = p.position.y } end
  local sp = c.force.get_spawn_position(c.surface)
  return { x = sp.x, y = sp.y }
end

function M.tick(task)
  local c = companion.get()
  if not c then
    return { status = "failed", detail = "the companion character is gone" }
  end
  local f = task._fight
  equipment.auto_arm(c)

  -- Reassess the local battle as health, ammunition and reinforcements change.
  if not f.next_assess or game.tick >= f.next_assess then
    f.next_assess = game.tick + 60
    local threat, support, armed, center, enemy_count, ally_count = tactical_balance(c)
    local hp = health_ratio(c)
    f.enemy_center = center
    f.last_balance = { enemies = enemy_count, allies = ally_count, armed = armed }
    if hp < task.flee_below
      or (enemy_count >= 2 and not armed and threat > support * 1.35)
      or (threat > support * 1.8) then
      f.forced_retreat = true
    end
  end

  if f.forced_retreat then
    stop_shooting(c)
    if not f.retreat then
      local dest = retreat_destination(c, f.enemy_center)
      f.retreat = {}
      walk.begin(f.retreat, c, dest, 3)
    end
    local r = walk.step(f.retreat, c, task.id)
    if r == "arrived" or type(r) == "table" then
      return {
        status = "done",
        detail = string.format("retreated after assessing the local battle; %s", kills_phrase(f.kills)),
      }
    end
    return nil
  end

  -- Current target (re-acquire when dead/invalid; count the kill if we were on it).
  local target = f.target
  if not (target and target.valid) then
    if f.engaged then
      f.kills = f.kills + 1
      f.engaged = false
    end
    target = pick_target(c, f, task.radius)
    f.target = target
    f.walk = nil
    if not target then
      stop_shooting(c)
      return { status = "done", detail = string.format("area cleared — %s", kills_phrase(f.kills)) }
    end
  end

  local gun = equipment.current_gun(c)
  local armed = gun ~= nil and total_ammo(c) > 0
  local attack_range = armed and gun_range(c) or MELEE_RANGE

  local dx, dy = target.position.x - c.position.x, target.position.y - c.position.y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist > math.max(attack_range - (armed and 1 or 0.25), 1.25) then
    stop_shooting(c)
    -- Walk toward the target; re-plan when it has drifted from the walk goal.
    if not f.walk or not f.walk_goal
      or math.abs(f.walk_goal.x - target.position.x) + math.abs(f.walk_goal.y - target.position.y) > 3 then
      f.walk = {}
      f.walk_goal = { x = target.position.x, y = target.position.y }
      walk.begin(f.walk, c, f.walk_goal, armed and math.max(attack_range - 2, 2) or 1.25)
    end
    local r = walk.step(f.walk, c, task.id)
    if type(r) == "table" then
      -- Unreachable (water in between?) — drop this target and look for another.
      f.target = nil
      f.walk = nil
    elseif r == "arrived" then
      f.walk = nil
    end
    return nil
  end

  f.engaged = true
  c.walking_state = { walking = false }
  if armed then
    c.shooting_state = {
      state = defines.shooting.shooting_enemies,
      position = { x = target.position.x, y = target.position.y },
    }
  else
    stop_shooting(c)
    -- Character shooting_state cannot reliably punch without a selected gun,
    -- so apply ordinary physical melee damage at a human-scale cadence.
    if game.tick >= f.next_melee_tick then
      f.next_melee_tick = game.tick + MELEE_COOLDOWN
      pcall(function() target.damage(MELEE_DAMAGE, c.force, "physical", c) end)
    end
  end
  return nil
end

return M
