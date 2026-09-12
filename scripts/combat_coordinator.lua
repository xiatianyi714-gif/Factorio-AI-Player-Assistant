-- Patrol squad coordination. A patrol sighting is shared with nearby patrol
-- companions so nests are not attacked by whichever helper happened to see
-- them first. Each helper still runs the normal tactical fight task and then
-- resumes its exact suspended patrol task.
local companion = require("scripts.companion")
local tasks = require("scripts.tasks")

local M = {}
local DETECTION_RADIUS = 30
local ASSIST_RADIUS = 96
local ENGAGEMENT_RADIUS = 40
local ENEMY_TYPES = { "unit", "unit-spawner", "turret" }

local function dist_sq(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

local function nearest_patrol_enemy(c)
  local best, best_d
  for _, enemy in ipairs(c.surface.find_entities_filtered({
    position = c.position,
    radius = DETECTION_RADIUS,
    force = game.forces.enemy,
    type = ENEMY_TYPES,
  })) do
    if enemy.valid then
      local d = dist_sq(c.position, enemy.position)
      if not best or d < best_d then best, best_d = enemy, d end
    end
  end
  return best
end

function M.on_tick()
  if game.tick % 15 ~= 0 then return end

  local alert
  for _, name in ipairs(companion.names()) do
    local active = tasks.active_summary(name)
    if active and active.type == "patrol" then
      local c = companion.get(name)
      local enemy = c and nearest_patrol_enemy(c)
      if enemy then
        alert = {
          surface = c.surface,
          position = { x = enemy.position.x, y = enemy.position.y },
        }
        break
      end
    end
  end
  if not alert then return end

  for _, name in ipairs(companion.names()) do
    local active = tasks.active_summary(name)
    local c = companion.get(name)
    if active and active.type == "patrol" and c and c.surface == alert.surface
        and dist_sq(c.position, alert.position) <= ASSIST_RADIUS * ASSIST_RADIUS then
      tasks.interrupt_for_combat(name, {
        type = "fight",
        target = alert.position,
        radius = ENGAGEMENT_RADIUS,
        flee_below = 0.3,
        tactical = true,
        squad_response = true,
      })
    end
  end
  companion.set_context(nil)
end

return M
