-- Gun/ammo/armor slots: the instant "equip" method plus read helpers for
-- perceive (companion.equipment) and the fight task. Guns and armor swap the
-- old item back into the main inventory; ammo tops up the slot paired with
-- the equipped gun (gun slot i shoots from ammo slot i).
local companion = require("scripts.companion")

local M = {}

local TYPE_PHRASE = { gun = "a gun", ammo = "ammo", armor = "armor" }

-- Return leftovers to the main inventory; anything that doesn't fit spills.
local function give_back(c, main, name, count)
  local inserted = main.insert({ name = name, count = count })
  if inserted < count then
    pcall(c.surface.spill_item_stack, {
      position = c.position,
      stack = { name = name, count = count - inserted },
      force = c.force,
    })
  end
end

local function checked_item(name, wanted_type)
  if type(name) ~= "string" then
    error("equip: " .. wanted_type .. " must be an item name string")
  end
  local proto = prototypes.item[name]
  if not proto then
    error("no item called '" .. name .. "'")
  end
  if proto.type ~= wanted_type then
    error(string.format("%s isn't %s — it can't go in the %s slot",
      name, TYPE_PHRASE[wanted_type], wanted_type))
  end
  return proto
end

-- Puts one `name` into a gun slot and returns the slot index. Prefers a slot
-- that already holds this gun, then an empty slot, then swaps the selected one.
local function equip_gun(c, main, name)
  local gun_inv = c.get_inventory(defines.inventory.character_guns)
  if not gun_inv or #gun_inv == 0 then
    error("I have no gun slots — that shouldn't happen for a character")
  end
  for i = 1, #gun_inv do
    local s = gun_inv[i]
    if s.valid_for_read and s.name == name then return i end
  end
  if main.get_item_count(name) == 0 then
    error("I don't have a " .. name .. " in my inventory — craft or pick one up first")
  end
  local target
  for i = 1, #gun_inv do
    if not gun_inv[i].valid_for_read then
      target = i
      break
    end
  end
  local old
  if not target then
    target = 1
    pcall(function()
      local idx = c.selected_gun_index
      if type(idx) == "number" and idx >= 1 and idx <= #gun_inv then target = idx end
    end)
    local s = gun_inv[target]
    old = { name = s.name, count = s.count }
  end
  main.remove({ name = name, count = 1 })
  local placed = false
  pcall(function() placed = gun_inv[target].set_stack({ name = name, count = 1 }) end)
  if not placed then
    main.insert({ name = name, count = 1 })
    error("couldn't put the " .. name .. " into a gun slot — the slot refused it")
  end
  if old then give_back(c, main, old.name, old.count) end
  return target
end

-- Loads as much `name` as fits (up to one stack) into the ammo slot paired
-- with `gun_slot` (or the selected gun's slot). Different ammo already in the
-- slot is swapped back to the main inventory.
local function equip_ammo(c, main, name, stack_size, gun_slot)
  local ammo_inv = c.get_inventory(defines.inventory.character_ammo)
  if not ammo_inv or #ammo_inv == 0 then
    error("I have no ammo slots — that shouldn't happen for a character")
  end
  local slot = gun_slot
  if not slot then
    pcall(function()
      local idx = c.selected_gun_index
      if type(idx) == "number" then slot = idx end
    end)
  end
  if type(slot) ~= "number" or slot < 1 or slot > #ammo_inv then slot = 1 end

  local stack = ammo_inv[slot]
  local current = (stack.valid_for_read and stack.name == name) and stack.count or 0
  local have = main.get_item_count(name)
  if have == 0 then
    if current > 0 then return end -- nothing to add, but it's already loaded
    error("I don't have any " .. name .. " in my inventory — craft some first")
  end

  local old
  if stack.valid_for_read and stack.name ~= name then
    old = { name = stack.name, count = stack.count }
  end

  local n = math.min(have, stack_size - current)
  if n <= 0 then return end -- already holding a full stack of this ammo
  main.remove({ name = name, count = n })
  local placed = false
  pcall(function()
    if current > 0 then
      stack.count = current + n
      placed = true
    else
      placed = stack.set_stack({ name = name, count = n })
    end
  end)
  if not placed then
    main.insert({ name = name, count = n })
    error("the " .. name .. " wouldn't go into the ammo slot — is it the right ammo for your gun?")
  end
  if old then give_back(c, main, old.name, old.count) end
end

local function equip_armor(c, main, name)
  local armor_inv = c.get_inventory(defines.inventory.character_armor)
  if not armor_inv or #armor_inv == 0 then
    error("I have no armor slot — that shouldn't happen for a character")
  end
  local stack = armor_inv[1]
  if stack.valid_for_read and stack.name == name then return end -- already wearing it
  if main.get_item_count(name) == 0 then
    error("I don't have a " .. name .. " in my inventory — craft or pick one up first")
  end
  local old
  if stack.valid_for_read then
    old = { name = stack.name, count = stack.count }
  end
  main.remove({ name = name, count = 1 })
  local placed = false
  pcall(function() placed = stack.set_stack({ name = name, count = 1 }) end)
  if not placed then
    main.insert({ name = name, count = 1 })
    error("couldn't put the " .. name .. " into the armor slot — the slot refused it")
  end
  -- Swapping armor can shrink the main inventory; overflow spills next to me.
  if old then give_back(c, main, old.name, old.count) end
end

-- ------------------------------------------------------------ read helpers

-- Currently usable gun: name, slot index — or nil when no gun is equipped.
-- Prefers the selected slot, falls back to the first slot holding a gun.
-- pcall-guarded so callers can trust it in any character state.
function M.current_gun(c)
  local name, slot
  pcall(function()
    local gun_inv = c.get_inventory(defines.inventory.character_guns)
    if not gun_inv then return end
    local idx = c.selected_gun_index
    if type(idx) == "number" and idx >= 1 and idx <= #gun_inv then
      local s = gun_inv[idx]
      if s.valid_for_read then
        name, slot = s.name, idx
        return
      end
    end
    for i = 1, #gun_inv do
      local s = gun_inv[i]
      if s.valid_for_read then
        name, slot = s.name, i
        return
      end
    end
  end)
  return name, slot
end

-- Ammo loaded for gun slot `slot` (guns shoot from the same-index ammo slot).
-- Returns name, count — or nil, 0 when the slot is empty.
function M.slot_ammo(c, slot)
  local name, count = nil, 0
  pcall(function()
    local ammo_inv = c.get_inventory(defines.inventory.character_ammo)
    if not ammo_inv or type(slot) ~= "number" or slot < 1 or slot > #ammo_inv then return end
    local s = ammo_inv[slot]
    if s.valid_for_read then
      name, count = s.name, s.count
    end
  end)
  return name, count
end

local AUTO_WEAPON_PAIRS = {
  { "combat-shotgun", "piercing-shotgun-shell" }, { "combat-shotgun", "shotgun-shell" },
  { "shotgun", "piercing-shotgun-shell" }, { "shotgun", "shotgun-shell" },
  { "submachine-gun", "uranium-rounds-magazine" }, { "submachine-gun", "piercing-rounds-magazine" },
  { "submachine-gun", "firearm-magazine" }, { "pistol", "uranium-rounds-magazine" },
  { "pistol", "piercing-rounds-magazine" }, { "pistol", "firearm-magazine" },
  { "rocket-launcher", "explosive-rocket" }, { "rocket-launcher", "rocket" },
  { "flamethrower", "flamethrower-ammo" },
}

-- Find a same-force chest that can complete a usable gun/ammunition pair.
-- The caller is responsible for physically walking into reach before taking.
function M.find_armament_chest(c, radius)
  local current, current_slot = M.current_gun(c)
  local _, loaded = M.slot_ammo(c, current_slot)
  local main = c.get_main_inventory()
  local best, best_distance
  for _, box in ipairs(c.surface.find_entities_filtered({
    position = c.position, radius = radius or 256, force = c.force,
    type = { "container", "logistic-container" },
  })) do
    local inv = box.get_inventory(defines.inventory.chest)
    if inv then
      for _, pair in ipairs(AUTO_WEAPON_PAIRS) do
        local gun, ammo = pair[1], pair[2]
        local gun_available = current == gun or main.get_item_count(gun) > 0 or inv.get_item_count(gun) > 0
        local ammo_available = main.get_item_count(ammo) > 0 or inv.get_item_count(ammo) > 0
        local supplies_something = inv.get_item_count(gun) > 0 or inv.get_item_count(ammo) > 0
        local may_use = not current or current == gun
          or (loaded == 0 and inv.get_item_count(gun) > 0)
        if may_use and gun_available and ammo_available and supplies_something then
          local dx, dy = box.position.x - c.position.x, box.position.y - c.position.y
          local distance = dx * dx + dy * dy
          if not best_distance or distance < best_distance then best, best_distance = box, distance end
          break
        end
      end
    end
  end
  return best
end

function M.take_armament_from_chest(c, box)
  if not (box and box.valid) then return false end
  local inv = box.get_inventory(defines.inventory.chest)
  if not inv then return false end
  local current, current_slot = M.current_gun(c)
  local _, loaded = M.slot_ammo(c, current_slot)
  local main = c.get_main_inventory()
  for _, pair in ipairs(AUTO_WEAPON_PAIRS) do
    local gun, ammo = pair[1], pair[2]
    local gun_available = current == gun or main.get_item_count(gun) > 0 or inv.get_item_count(gun) > 0
    local ammo_available = main.get_item_count(ammo) > 0 or inv.get_item_count(ammo) > 0
    local may_use = not current or current == gun
      or (loaded == 0 and inv.get_item_count(gun) > 0)
    if may_use and gun_available and ammo_available then
      if current ~= gun and main.get_item_count(gun) == 0 then
        local moved = main.insert({ name = gun, count = math.min(1, inv.get_item_count(gun)) })
        if moved > 0 then inv.remove({ name = gun, count = moved }) end
      end
      if main.get_item_count(ammo) == 0 then
        local stack_size = prototypes.item[ammo] and prototypes.item[ammo].stack_size or 100
        local moved = main.insert({ name = ammo, count = math.min(stack_size, inv.get_item_count(ammo)) })
        if moved > 0 then inv.remove({ name = ammo, count = moved }) end
      end
      if current ~= gun then
        local ok = pcall(M.equip, { gun = gun, ammo = ammo })
        return ok and M.current_gun(c) == gun
      end
      return M.auto_arm(c)
    end
  end
  return false
end

local function take_from_reachable_chest(c, name, count)
  for _, box in ipairs(c.surface.find_entities_filtered({
    position = c.position,
    radius = c.reach_distance,
    force = c.force,
    type = { "container", "logistic-container" },
  })) do
    local inv = box.get_inventory(defines.inventory.chest)
    if inv then
      local n = math.min(inv.get_item_count(name), count)
      if n > 0 then
        local moved = c.get_main_inventory().insert({ name = name, count = n })
        if moved > 0 then
          inv.remove({ name = name, count = moved })
          return moved
        end
      end
    end
  end
  return 0
end

-- Ensure a usable gun and loaded ammo slot using only items already carried
-- or physically reachable in a same-force chest. Safe to call every tick.
function M.auto_arm(c)
  local current, slot = M.current_gun(c)
  local _, loaded = M.slot_ammo(c, slot)
  if current and loaded > 0 then return true end
  local rec = companion.record()
  if rec and rec.auto_arm_retry_tick and game.tick < rec.auto_arm_retry_tick then return false end
  if rec then rec.auto_arm_retry_tick = game.tick + 60 end
  local main = c.get_main_inventory()

  local function try_pair(pair)
    local gun, ammo = pair[1], pair[2]
    if current and current ~= gun then return false end
    if not current and main.get_item_count(gun) == 0 then take_from_reachable_chest(c, gun, 1) end
    if not current and main.get_item_count(gun) == 0 then return false end
    if main.get_item_count(ammo) == 0 then
      local stack = prototypes.item[ammo] and prototypes.item[ammo].stack_size or 100
      take_from_reachable_chest(c, ammo, stack)
    end
    if main.get_item_count(ammo) == 0 then return false end
    local params = { ammo = ammo }
    if not current then params.gun = gun end
    M.equip(params)
    if rec then rec.auto_arm_retry_tick = nil end
    return true
  end

  if current then
    for _, pair in ipairs(AUTO_WEAPON_PAIRS) do
      if pair[1] == current and try_pair(pair) then return true end
    end
  else
    for _, pair in ipairs(AUTO_WEAPON_PAIRS) do
      if try_pair(pair) then return true end
    end
  end
  return false
end

-- Equipment snapshot for perceive's companion block:
-- { gun = <name|nil>, ammo = {name: count}, armor = <name|nil> }.
-- Nil-safe and pcall-guarded — never raises.
function M.summary(c)
  local out = { ammo = {} }
  if not (c and c.valid) then return out end
  out.gun = M.current_gun(c)
  pcall(function()
    local ammo_inv = c.get_inventory(defines.inventory.character_ammo)
    if ammo_inv then
      for i = 1, #ammo_inv do
        local s = ammo_inv[i]
        if s.valid_for_read then
          out.ammo[s.name] = (out.ammo[s.name] or 0) + s.count
        end
      end
    end
    local armor_inv = c.get_inventory(defines.inventory.character_armor)
    if armor_inv and #armor_inv >= 1 and armor_inv[1].valid_for_read then
      out.armor = armor_inv[1].name
    end
  end)
  return out
end

-- --------------------------------------------------------------- rpc: equip

function M.equip(params)
  local c = companion.require_companion()
  if params.gun == nil and params.ammo == nil and params.armor == nil then
    error("equip needs at least one of gun, ammo, armor — item names from my inventory,"
      .. " e.g. gun=\"pistol\", ammo=\"firearm-magazine\"")
  end
  local main = c.get_main_inventory()

  local gun_slot
  if params.gun ~= nil then
    checked_item(params.gun, "gun")
    gun_slot = equip_gun(c, main, params.gun)
    pcall(function() c.selected_gun_index = gun_slot end)
  end
  if params.ammo ~= nil then
    local proto = checked_item(params.ammo, "ammo")
    equip_ammo(c, main, params.ammo, proto.stack_size or 1, gun_slot)
  end
  if params.armor ~= nil then
    checked_item(params.armor, "armor")
    equip_armor(c, main, params.armor)
  end
  -- Selecting a gun slot can fail while its ammo slot is empty — retry now
  -- that ammo may have been loaded.
  if gun_slot then
    pcall(function() c.selected_gun_index = gun_slot end)
  end
  return M.summary(c)
end

return M
