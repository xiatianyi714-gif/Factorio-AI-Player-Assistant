-- Small autonomous jobs for companions with no player-assigned work.
-- Jobs are deliberately short so explicit commands take over naturally.
local companion = require("scripts.companion")
local tasks = require("scripts.tasks")
local equipment = require("scripts.equipment")
local refuel = require("scripts.actions.refuel")
local repair = require("scripts.actions.repair")

local M = {}
local ENEMY_TYPES = { "unit", "unit-spawner", "turret" }
local AUTO_SMELT_RADIUS = 256
local AUTO_SMELT_BATCH = 50
local smelting_categories_by_item

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

local function autonomous_smelting_task(c)
  local available = {}
  for _, stack in ipairs(c.get_main_inventory().get_contents()) do
    available[stack.name] = (available[stack.name] or 0) + stack.count
  end
  for _, box in ipairs(c.surface.find_entities_filtered({
    position = c.position,
    radius = AUTO_SMELT_RADIUS,
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
    position = c.position,
    radius = AUTO_SMELT_RADIUS,
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

local function random_minable(c)
  local list = {}
  for _, e in ipairs(c.surface.find_entities_filtered({
    position = c.position,
    radius = 20,
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

local function wander_task(c)
  local angle = math.random() * math.pi * 2
  local distance = math.random(8, 20)
  local desired = {
    x = c.position.x + math.cos(angle) * distance,
    y = c.position.y + math.sin(angle) * distance,
  }
  local target = c.surface.find_non_colliding_position("character", desired, 10, 0.5)
  if not target then return nil end
  return { type = "walk_to", target = { x = target.x, y = target.y }, arrive_within = 1.5 }
end

function M.update()
  local assigned = { repair = 0, refuel = 0, smelt = 0, mine = 0, patrol = 0 }
  -- Include autonomous work that is already running when enforcing the
  -- two-helper limit.
  for _, name in ipairs(companion.names()) do
    local active = tasks.active_summary(name)
    if active then
      if active.type == "keep_repaired" then assigned.repair = assigned.repair + 1
      elseif active.type == "keep_fueled" then assigned.refuel = assigned.refuel + 1
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
        local enemy = nearby_enemy(c)
        if enemy and equipment.auto_arm(c) then
          task = { type = "fight", target = { x = c.position.x, y = c.position.y }, radius = 30 }
        elseif assigned.repair < 2 and repair.has_work(c, 256) then
          task = { type = "keep_repaired", radius = 256, max_empty_scans = 1 }
          assigned.repair = assigned.repair + 1
        elseif assigned.refuel < 2 and refuel.has_work(c, 256, storage.autonomy_fuel_target or 10) then
          task = {
            type = "keep_fueled", radius = 256,
            top_up_count = storage.autonomy_fuel_target or 10,
            max_empty_scans = 1,
          }
          assigned.refuel = assigned.refuel + 1
        elseif assigned.smelt < 2 then
          task = autonomous_smelting_task(c)
          if task then assigned.smelt = assigned.smelt + 1 end
        end
        if not task and assigned.patrol < 2 then
          task = { type = "patrol", radius = 12, rounds = 1 }
          assigned.patrol = assigned.patrol + 1
        elseif not task and assigned.mine < 2 then
          local target = random_minable(c)
          if target then
            if target.type == "resource" then
              task = { type = "mine", resource = target.name, count = 20 }
            else
              task = { type = "mine", target = { x = target.position.x, y = target.position.y } }
            end
            assigned.mine = assigned.mine + 1
          end
        end
        -- Mining is deliberately the lowest-priority useful idle job. It is
        -- considered only after combat, repairs, refueling, and patrol.
        task = task or wander_task(c)
        if task then
          tasks.enqueue({ task = task, replace = false, background = true, quiet = true })
        end
      end
    end
  end
  companion.set_context(nil)
end

return M
