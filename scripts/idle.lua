-- Small autonomous jobs for companions with no player-assigned work.
-- Jobs are deliberately short so explicit commands take over naturally.
local companion = require("scripts.companion")
local tasks = require("scripts.tasks")
local equipment = require("scripts.equipment")
local refuel = require("scripts.actions.refuel")
local repair = require("scripts.actions.repair")
local turret_supply = require("scripts.actions.turret_supply")
local arm_self = require("scripts.actions.arm_self")
local machine_supply = require("scripts.machine_supply")

local M = {}
local ENEMY_TYPES = { "unit", "unit-spawner", "turret" }
local AUTO_SMELT_RADIUS = 256
local AUTO_SMELT_BATCH = 50
local smelting_categories_by_item
local WORK_ORDER = { "repair", "refuel", "turret", "patrol", "smelt", "mine" }
local DEFAULT_PRIORITY = { repair = 1, refuel = 2, turret = 3, patrol = 4, smelt = 5, mine = 6 }

local function work_radius(name)
  local saved = storage.work_settings and storage.work_settings[name]
  return math.max(32, math.min(512, math.floor(tonumber(saved and saved.radius) or 256)))
end

local function work_center(name, c)
  local saved = storage.work_settings and storage.work_settings[name]
  if saved and saved.center and (not saved.surface_index or saved.surface_index == c.surface.index) then
    return { x = saved.center.x, y = saved.center.y }
  end
  return { x = c.position.x, y = c.position.y }
end

local function priority(name, work)
  local saved = storage.work_priorities and storage.work_priorities[name]
  local value = saved and saved[work]
  if value == nil then value = DEFAULT_PRIORITY[work] end
  return math.max(0, math.min(6, math.floor(tonumber(value) or 0)))
end

local function ordered_work(name)
  local out = {}
  -- Rotate equal-priority jobs so an always-available patrol does not starve
  -- mining (or another job) forever. Different companions start at different
  -- offsets, which also encourages useful division of labour.
  local name_offset = 0
  for i = 1, #name do name_offset = name_offset + string.byte(name, i) end
  local rotation = (math.floor(game.tick / 600) + name_offset) % #WORK_ORDER
  for order, work in ipairs(WORK_ORDER) do
    local value = priority(name, work)
    if value > 0 then
      out[#out + 1] = { key = work, priority = value, order = (order + rotation) % #WORK_ORDER }
    end
  end
  table.sort(out, function(a, b)
    return a.priority < b.priority or (a.priority == b.priority and a.order < b.order)
  end)
  return out
end

local function smelting_items()
  if smelting_categories_by_item then return smelting_categories_by_item end
  smelting_categories_by_item = {}
  for _, recipe in pairs(prototypes.recipe) do
    local category = recipe.category or "crafting"
    for _, ingredient in ipairs(recipe.ingredients or {}) do
      if ingredient.type == "item" then
        local categories = smelting_categories_by_item[ingredient.name] or {}
        categories[category] = true
        smelting_categories_by_item[ingredient.name] = categories
      end
    end
  end
  return smelting_categories_by_item
end

local function autonomous_smelting_task(c, radius, center)
  local available = {}
  for _, stack in ipairs(c.get_main_inventory().get_contents()) do
    available[stack.name] = (available[stack.name] or 0) + stack.count
  end
  for _, box in ipairs(c.surface.find_entities_filtered({
    position = center or c.position,
    radius = radius or AUTO_SMELT_RADIUS,
    force = c.force,
    type = { "container", "logistic-container" },
  })) do
    local inv = box.get_inventory(defines.inventory.chest)
    if inv then
      for _, stack in ipairs(inv.get_contents()) do
        available[stack.name] = (available[stack.name] or 0) + stack.count
      end
    end
  end
  if not next(available) then return nil end
  local candidates = smelting_items()
  local furnaces = c.surface.find_entities_filtered({
    position = center or c.position,
    radius = radius or AUTO_SMELT_RADIUS,
    force = c.force,
    type = "furnace",
  })
  local best, best_item, best_count, best_distance
  for item_name, item_count in pairs(available) do
    local categories = candidates[item_name]
    if categories then
      for _, furnace in ipairs(furnaces) do
        local supported = false
        for category in pairs(furnace.prototype.crafting_categories or {}) do
          if categories[category] then supported = true; break end
        end
        local accepts = false
        if supported then
          pcall(function() accepts = furnace.can_insert({ name = item_name, count = 1 }) end)
        end
        if accepts then
          local dx, dy = furnace.position.x - c.position.x, furnace.position.y - c.position.y
          local distance = dx * dx + dy * dy
          if not best_distance or distance < best_distance then
            best, best_item, best_count, best_distance = furnace, item_name, item_count, distance
          end
        end
      end
    end
  end
  if not best then return nil end
  return {
    type = "supply_input",
    item = best_item,
    count = math.min(best_count, AUTO_SMELT_BATCH),
    target = { x = best.position.x, y = best.position.y },
    autonomous_smelt = true,
    find_in_chests = true,
  }
end

local function random_minable(c, radius, center)
  local list = {}
  for _, e in ipairs(c.surface.find_entities_filtered({
    position = center or c.position,
    radius = math.min(tonumber(radius) or 20, 64),
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

local function wander_task(c, center, radius)
  local angle = math.random() * math.pi * 2
  local distance = math.random(8, 20)
  local origin = center or c.position
  distance = math.min(distance, math.max(4, tonumber(radius) or distance))
  local desired = {
    x = origin.x + math.cos(angle) * distance,
    y = origin.y + math.sin(angle) * distance,
  }
  local target = c.surface.find_non_colliding_position("character", desired, 10, 0.5)
  if not target then return nil end
  return { type = "walk_to", target = { x = target.x, y = target.y }, arrive_within = 1.5 }
end

function M.update()
  if storage.autonomy_paused then return end
  local assigned = { repair = 0, refuel = 0, turret = 0, smelt = 0, mine = 0, patrol = 0 }
  -- Include autonomous work that is already running when enforcing the
  -- two-helper limit.
  for _, name in ipairs(companion.names()) do
    local active = tasks.active_summary(name)
    if active then
      if active.type == "keep_repaired" then assigned.repair = assigned.repair + 1
      elseif active.type == "keep_fueled" then assigned.refuel = assigned.refuel + 1
      elseif active.type == "turret_supply" then assigned.turret = assigned.turret + 1
      elseif active.type == "supply_input" then assigned.smelt = assigned.smelt + 1
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
        local radius = work_radius(name)
        local center = work_center(name, c)
        local enemy = nearby_enemy(c)
        -- Prepare before optional chores so a helper is armed when danger
        -- arrives instead of noticing a distant supply chest too late.
        task = arm_self.find_task(c, radius)
        if not task and enemy and equipment.auto_arm(c) then
          task = { type = "fight", target = { x = c.position.x, y = c.position.y }, radius = 30 }
        elseif not task then
          for _, work in ipairs(ordered_work(name)) do
            if work.key == "repair" and assigned.repair < 2 and repair.has_work(c, radius, center) then
              task = { type = "keep_repaired", center = center, radius = radius, max_empty_scans = 1 }
            elseif work.key == "refuel" and assigned.refuel < 2
                and refuel.has_work(c, radius, storage.autonomy_fuel_target or 10, center) then
              task = { type = "keep_fueled", center = center, radius = radius,
                top_up_count = storage.autonomy_fuel_target or 10, max_empty_scans = 1 }
            elseif work.key == "turret" and assigned.turret < 2 then
              task = turret_supply.find_task(c, radius, storage.autonomy_turret_ammo_target or 10, center)
            elseif work.key == "smelt" and assigned.smelt < 2 then
              task = machine_supply.find_task(c, radius, center)
            elseif work.key == "patrol" and assigned.patrol < 2 then
              local rec = companion.record(name)
              local saved = rec and rec.saved_patrol_route
              if saved and #saved >= 2 then
                local points = {}
                for i, point in ipairs(saved) do points[i] = { x = point.x, y = point.y } end
                task = { type = "patrol", points = points, rounds = 1 }
              end
            elseif work.key == "mine" and assigned.mine < 2 then
              local target = random_minable(c, radius, center)
              if target then
                task = target.type == "resource"
                  and { type = "mine", resource = target.name, count = 20,
                    search_center = center, search_radius = radius }
                  or { type = "mine", target = { x = target.position.x, y = target.position.y } }
              end
            end
            if task then
              assigned[work.key] = assigned[work.key] + 1
              break
            end
          end
        end
        -- No unconditional wandering fallback. If no enabled work exists, the
        -- helper stays where it is; patrol movement must be explicitly enabled
        -- through priorities, a guard role, or a direct patrol order.
        if task then
          task.autonomous = true
          tasks.enqueue({ task = task, replace = false, background = true, quiet = true })
        end
      end
    end
  end
  companion.set_context(nil)
end

return M
