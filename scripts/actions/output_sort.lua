-- Persistent classified output collection driven by storage.output_routes.
-- Each route binds one product on one production entity to one destination.
local companion = require("scripts.companion")
local approach = require("scripts.actions.approach")

local M = {}
local SCAN_TICKS = 120
local LOCK_TICKS = 600

local function output_inventory(source)
  local inv
  pcall(function() inv = source.get_output_inventory() end)
  return inv
end

local function distance_sq(a, b)
  local x, y = a.x - b.x, a.y - b.y
  return x * x + y * y
end

function M.start(task)
  companion.require_companion()
  task.batch = math.max(1, math.min(math.floor(tonumber(task.batch) or 50), 1000))
  task._sort = { next_scan = 0 }
end

local function release(job)
  if job and storage.output_route_locks[job.key] then
    storage.output_route_locks[job.key] = nil
  end
end

local function choose_job(c, task)
  local best, best_d
  for key, route in pairs(storage.output_routes or {}) do
    local source, destination = route.source, route.destination
    if source and source.valid and destination and destination.valid then
      local inv = output_inventory(source)
      local count = inv and inv.get_item_count(route.item) or 0
      local accepts = false
      pcall(function() accepts = destination.can_insert({ name = route.item, count = 1 }) end)
      local lock = storage.output_route_locks[key]
      local free = not lock or game.tick - (lock.tick or 0) > LOCK_TICKS or lock.name == companion.context()
      if count > 0 and accepts and free then
        local d = distance_sq(c.position, source.position)
        if not best or d < best_d then best, best_d = { key = key, route = route }, d end
      end
    end
  end
  if best then storage.output_route_locks[best.key] = { name = companion.context(), tick = game.tick } end
  return best
end

function M.tick(task)
  local c = companion.get()
  if not c then return { status = "failed", detail = "助手已不存在" } end
  local s = task._sort
  if not s.job then
    if game.tick < s.next_scan then c.walking_state = { walking = false }; return nil end
    s.next_scan = game.tick + SCAN_TICKS
    s.job = choose_job(c, task)
    if not s.job then c.walking_state = { walking = false }; return nil end
    s.phase = "take"
    task._approach = nil
  end

  local route = s.job.route
  if not (route.source and route.source.valid and route.destination and route.destination.valid) then
    release(s.job); s.job = nil; task._approach = nil; return nil
  end

  if s.phase == "take" then
    local reached = approach.ensure(task, c, route.source.position, c.reach_distance)
    if type(reached) == "table" then release(s.job); s.job = nil; task._approach = nil; return nil end
    if reached ~= "ok" then return nil end
    local inv = output_inventory(route.source)
    local n = inv and math.min(inv.get_item_count(route.item), task.batch) or 0
    local moved = n > 0 and c.get_main_inventory().insert({ name = route.item, count = n }) or 0
    if moved > 0 then inv.remove({ name = route.item, count = moved }) end
    if moved <= 0 then release(s.job); s.job = nil; task._approach = nil; return nil end
    s.carried = moved
    s.phase = "store"
    task._approach = nil
    return nil
  end

  local reached = approach.ensure(task, c, route.destination.position, c.reach_distance)
  if type(reached) == "table" then release(s.job); s.job = nil; task._approach = nil; return nil end
  if reached ~= "ok" then return nil end
  local have = math.min(s.carried or 0, c.get_item_count(route.item))
  local inserted = have > 0 and route.destination.insert({ name = route.item, count = have }) or 0
  if inserted > 0 then c.remove_item({ name = route.item, count = inserted }) end
  release(s.job)
  s.job, s.carried, s.phase = nil, nil, nil
  task._approach = nil
  s.next_scan = game.tick + 30
  return nil
end

return M
