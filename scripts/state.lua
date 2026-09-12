local M = {}

-- Initializes/migrates the storage schema. Safe to call repeatedly.
-- All fields any module needs MUST be declared here (single owner of the schema).
function M.init()
  storage.local_language = storage.local_language or "zh"
  storage.autonomy_turret_ammo_target = storage.autonomy_turret_ammo_target or 10
  if storage.autonomy_paused == nil then storage.autonomy_paused = false end
  storage.work_priorities = storage.work_priorities or {}
  storage.work_settings = storage.work_settings or {}
  storage.work_reservations = storage.work_reservations or {}
  storage.chat = storage.chat or { messages = {}, next_id = 1 }

  -- Tasks: one lane (queue + active) per companion.
  storage.tasks = storage.tasks or {}
  storage.tasks.next_id = storage.tasks.next_id or 1
  storage.tasks.records = storage.tasks.records or {}
  storage.tasks.by_companion = storage.tasks.by_companion or {}
  -- chain id -> failure tick: late enqueues of a failed plan cancel instantly
  storage.tasks.failed_chains = storage.tasks.failed_chains or {}
  if storage.tasks.queue or storage.tasks.active then
    -- migrate the pre-multi-companion single lane
    storage.tasks.by_companion["AI"] = {
      queue = storage.tasks.queue or {},
      active = storage.tasks.active,
    }
    storage.tasks.queue, storage.tasks.active = nil, nil
  end

  -- Companions: named registry; migrate the old single-companion record.
  storage.companions = storage.companions or {}
  if storage.companion then
    if storage.companion.entity then
      storage.companions["AI"] = storage.companion
    end
    storage.companion = nil
  end
  if not storage.companion_primary or not storage.companions[storage.companion_primary] then
    storage.companion_primary = next(storage.companions)
  end

  -- pathfinder bookkeeping: request id -> {name, task_id} (see actions/walk.lua)
  storage.path_requests = {}
  -- chunked RPC responses: { next_id, by_id = { [id] = { parts = {...}, created_tick } } }
  storage.rpc_outbox = storage.rpc_outbox or { next_id = 1, by_id = {} }
  -- push events for the brain (see scripts/events.lua): ring buffer like chat
  storage.events = storage.events or { list = {}, next_id = 1 }
  storage.output_routes = storage.output_routes or {}
  storage.output_route_locks = storage.output_route_locks or {}
  storage.machine_supply_rules = storage.machine_supply_rules or {}

  -- One-time 0.15.2 migration: an unchanged old Generalist preset enabled
  -- patrol at priority 4. Disable only that exact preset so deliberate custom
  -- patrol settings remain untouched, and stop its already-running idle job.
  if not storage.migrated_quiet_idle_0152 then
    for _, p in pairs(storage.work_priorities) do
      if p.repair == 1 and p.refuel == 2 and p.turret == 3 and p.smelt == 4
          and p.patrol == 4 and p.mine == 4 then
        p.patrol = 0
      end
    end
    storage.migrated_quiet_idle_0152 = true
    storage.stop_old_autonomous_tasks = true
  end
  if not storage.migrated_saved_patrol_0153 then
    for name, rec in pairs(storage.companions) do
      if rec.saved_patrol_route and #rec.saved_patrol_route >= 2 then
        storage.work_priorities[name] = storage.work_priorities[name] or {}
        if not storage.work_priorities[name].patrol or storage.work_priorities[name].patrol == 0 then
          storage.work_priorities[name].patrol = 4
        end
      end
    end
    storage.migrated_saved_patrol_0153 = true
  end
  if not storage.migrated_six_priorities_0154 then
    for _, p in pairs(storage.work_priorities) do
      -- Migrate only the unchanged old Generalist tail. Custom roles and
      -- deliberately chosen mining priorities remain untouched.
      if p.repair == 1 and p.refuel == 2 and p.turret == 3
          and p.patrol == 4 and p.smelt == 4 and p.mine == 4 then
        p.smelt, p.mine = 5, 6
      end
    end
    storage.migrated_six_priorities_0154 = true
  end
end

return M
