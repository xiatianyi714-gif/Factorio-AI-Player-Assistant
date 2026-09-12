-- Shared short-lived target reservations. They prevent multiple companions
-- selecting the same machine/resource while remaining self-healing if a task,
-- entity or companion disappears unexpectedly.
local M = {}
local TTL = 60 * 30

local function records()
  storage.work_reservations = storage.work_reservations or {}
  return storage.work_reservations
end

function M.key(entity)
  if not (entity and entity.valid) then return nil end
  local id = entity.unit_number
  if id then return tostring(entity.surface.index) .. ":u:" .. tostring(id) end
  return string.format("%d:p:%s:%.3f:%.3f", entity.surface.index, entity.name,
    entity.position.x, entity.position.y)
end

local function live(rec)
  return rec and (rec.expires or 0) > game.tick
end

function M.available(entity, owner, task_id)
  local key = M.key(entity)
  if not key then return false end
  local rec = records()[key]
  if not live(rec) then records()[key] = nil; return true end
  return rec.owner == owner and (not task_id or rec.task_id == task_id)
end

function M.claim(entity, owner, task_id)
  local key = M.key(entity)
  if not key or not M.available(entity, owner, task_id) then return false end
  records()[key] = { owner = owner, task_id = task_id, expires = game.tick + TTL }
  return true
end

function M.claim_key(key, owner, task_id)
  if not key then return true end
  local rec = records()[key]
  if live(rec) and rec.owner ~= owner then return false end
  records()[key] = { owner = owner, task_id = task_id, expires = game.tick + TTL }
  return true
end

function M.release(entity, task_id)
  local key = M.key(entity)
  if not key then return end
  local rec = records()[key]
  if rec and (task_id == nil or rec.task_id == task_id) then records()[key] = nil end
end

function M.release_task(task_id)
  for key, rec in pairs(records()) do
    if rec.task_id == task_id or not live(rec) then records()[key] = nil end
  end
end

function M.cleanup()
  for key, rec in pairs(records()) do
    if not live(rec) then records()[key] = nil end
  end
end

return M
