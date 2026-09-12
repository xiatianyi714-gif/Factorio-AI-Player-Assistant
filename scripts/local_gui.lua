local companion = require("scripts.companion")
local tasks = require("scripts.tasks")
local equipment = require("scripts.equipment")
local blueprint = require("scripts.blueprint")

local M = {}
local PREFIX = "agentic_local_"
local command_names

local function command_speech(text)
  if string.find(text, "跟随", 1, true) then return "跟着我！" end
  if string.find(text, "镇守", 1, true) then return "守住这里！" end
  if string.find(text, "巡逻", 1, true) then return "去附近巡逻！" end
  if string.find(text, "清理附近敌人", 1, true) then return "清理附近的敌人！" end
  if string.find(text, "补齐", 1, true) or string.find(text, "补充燃料", 1, true) then
    return "去检查设备并补充燃料！"
  end
  if string.find(text, "采集", 1, true) and string.find(text, "生产", 1, true) then
    return "开始采集、生产并收纳！"
  end
  if string.find(text, "采集", 1, true) or string.find(text, "采矿", 1, true) then
    return "去采集指定资源！"
  end
  if string.find(text, "收纳", 1, true) or string.find(text, "运送", 1, true) then
    return "把成品送到指定箱子！"
  end
  if string.find(text, "停止", 1, true) then return "停止当前命令！" end
  if string.find(text, "建造", 1, true) then return "开始建造！" end
  if string.find(text, "拆除", 1, true) then return "拆除这些目标！" end
  if string.find(text, "装备", 1, true) then return "检查并装备武器！" end
  return nil
end

local function status(player, text)
  local failed = string.find(text, "失败", 1, true) ~= nil
  if not failed then
    player.print({ "", "[本地助手] ", text })
    local speech = command_speech(text)
    if speech then
      pcall(function()
        player.create_local_flying_text({
          text = speech,
          position = { x = player.position.x, y = player.position.y - 2 },
          color = { r = 0.3, g = 1, b = 0.45 },
          time_to_live = 180,
          speed = 0.02,
        })
      end)
    end
  end
  local panel = player.gui.left[PREFIX .. "panel"]
  if panel and panel.valid then panel[PREFIX .. "status"].caption = text end
end

local function make_gui(player)
  if not player.gui.top[PREFIX .. "toggle"] then
    player.gui.top.add({ type = "button", name = PREFIX .. "toggle", caption = "助手命令", tooltip = "纯本地控制，不使用 AI 或 Token" })
  end
  if player.gui.left[PREFIX .. "panel"] then return end
  local frame = player.gui.left.add({ type = "frame", name = PREFIX .. "panel", caption = "战斗施工助手", direction = "vertical" })
  frame.visible = false
  frame.add({ type = "label", caption = "指令对象" })
  local target_items = { "全部助手" }
  for _, name in ipairs(companion.names()) do target_items[#target_items + 1] = name end
  frame.add({ type = "drop-down", name = PREFIX .. "target", items = target_items, selected_index = 1 })
  frame.add({ type = "label", caption = "补给只从助手能伸手够到的己方箱子获取" })
  local supply = frame.add({ type = "table", name = PREFIX .. "supply_controls", column_count = 2 })
  supply.add({ type = "button", name = PREFIX .. "spawn", caption = "增加 AI" })
  supply.add({ type = "button", name = PREFIX .. "remove", caption = "减少 AI" })
  supply.add({ type = "button", name = PREFIX .. "equip", caption = "装备现有武器" })
  supply.add({ type = "button", name = PREFIX .. "refuel", caption = "补齐燃料" })
  supply.add({ type = "label", caption = "设备燃料目标数量" })
  supply.add({ type = "textfield", name = PREFIX .. "fuel_count", text = tostring(storage.autonomy_fuel_target or 10), numeric = true, allow_decimal = false, allow_negative = false })
  supply.add({ type = "label", caption = "每次投入数量" })
  supply.add({ type = "textfield", name = PREFIX .. "supply_count", text = "50", numeric = true, allow_decimal = false, allow_negative = false })
  supply.add({ type = "label", caption = "每采集多少去投" })
  supply.add({ type = "textfield", name = PREFIX .. "harvest_count", text = "50", numeric = true, allow_decimal = false, allow_negative = false })
  frame.add({ type = "label", caption = "移动与战斗" })
  local move = frame.add({ type = "table", column_count = 2 })
  move.add({ type = "button", name = PREFIX .. "follow", caption = "跟随我" })
  move.add({ type = "button", name = PREFIX .. "hold", caption = "原地镇守" })
  move.add({ type = "button", name = PREFIX .. "patrol", caption = "巡逻" })
  move.add({ type = "button", name = PREFIX .. "attack", caption = "清理敌人" })
  move.add({ type = "button", name = PREFIX .. "stop", caption = "停止命令" })
  frame.add({ type = "label", caption = "施工（材料取自助手背包）" })
  local build = frame.add({ type = "table", column_count = 2 })
  build.add({ type = "button", name = PREFIX .. "build", caption = "框选建造蓝图" })
  build.add({ type = "button", name = PREFIX .. "demolish", caption = "框选拆除" })
  build.add({ type = "button", name = PREFIX .. "mine_supply", caption = "采集·生产·收纳" })
  build.add({ type = "button", name = PREFIX .. "blueprints", caption = "蓝图施工" })
  frame.add({ type = "label", name = PREFIX .. "status", caption = "就绪" })
end

local function close_blueprint_picker(player)
  local picker = player.gui.center[PREFIX .. "blueprint_picker"]
  if picker and picker.valid then picker.destroy() end
end

local function close_blueprint_materials(player)
  local frame = player.gui.screen[PREFIX .. "blueprint_materials"]
  if frame and frame.valid then frame.destroy() end
end

local function show_blueprint_materials(player, info)
  close_blueprint_materials(player)
  local frame = player.gui.screen.add({
    type = "frame", name = PREFIX .. "blueprint_materials",
    caption = info.label .. "：施工材料", direction = "vertical",
  })
  frame.auto_center = true
  frame.add({ type = "label", caption = "建筑虚影：" .. tostring(info.entity_count) .. " 个" })
  local table_gui = frame.add({ type = "table", column_count = 4 })
  table_gui.add({ type = "label", caption = "材料" })
  table_gui.add({ type = "label", caption = "需要" })
  table_gui.add({ type = "label", caption = "助手现有" })
  table_gui.add({ type = "label", caption = "缺少" })
  local names = {}
  for item in pairs(info.items_needed or {}) do names[#names + 1] = item end
  table.sort(names)
  for _, item in ipairs(names) do
    local have = 0
    for _, who in ipairs(command_names(player)) do
      local c = companion.get(who)
      if c then have = have + c.get_item_count(item) end
    end
    local needed = info.items_needed[item]
    table_gui.add({ type = "label", caption = prototypes.item[item] and prototypes.item[item].localised_name or item })
    table_gui.add({ type = "label", caption = tostring(needed) })
    table_gui.add({ type = "label", caption = tostring(have) })
    table_gui.add({ type = "label", caption = tostring(math.max(0, needed - have)) })
  end
  frame.add({ type = "button", name = PREFIX .. "blueprint_materials_close", caption = "关闭材料清单" })
end

local function close_mining_picker(player)
  local picker = player.gui.center[PREFIX .. "mining_picker"]
  if picker and picker.valid then picker.destroy() end
end

local function close_mining_destination(player)
  local picker = player.gui.center[PREFIX .. "mining_destination"]
  if picker and picker.valid then picker.destroy() end
end

local function close_supply_picker(player)
  local picker = player.gui.center[PREFIX .. "supply_picker"]
  if picker and picker.valid then picker.destroy() end
end

local function close_work_mode(player)
  local picker = player.gui.center[PREFIX .. "work_mode"]
  if picker and picker.valid then picker.destroy() end
end

local function close_output_picker(player)
  local picker = player.gui.center[PREFIX .. "output_picker"]
  if picker and picker.valid then picker.destroy() end
end

local function select_output_destination(player, source, item)
  local state = storage.local_gui[player.index]
  state.pending_output = {
    source = source, item = item, companions = command_names(player),
    full = state.pending_full,
  }
  close_output_picker(player)
  player.clear_cursor()
  player.cursor_stack.set_stack({ name = "agentic-local-output-destination-tool", count = 1 })
  status(player, "已选择成品 " .. item .. "；请框选它对应的己方箱子")
end

local function output_products(source, raw_item)
  local found = {}
  local inv
  pcall(function() inv = source.get_output_inventory() end)
  if inv then for _, stack in ipairs(inv.get_contents()) do found[stack.name] = true end end
  pcall(function()
    local recipe = source.get_recipe()
    if recipe then
      for _, product in ipairs(recipe.products or {}) do
        if product.type == "item" then found[product.name] = true end
      end
    end
  end)
  -- Empty furnaces often have no active recipe. Infer compatible recipes
  -- from the selected raw material and the machine's crafting categories.
  if raw_item then
    local categories = source.prototype.crafting_categories or {}
    for _, recipe in pairs(prototypes.recipe) do
      if categories[recipe.category] then
        local uses_raw = false
        for _, ingredient in ipairs(recipe.ingredients or {}) do
          if ingredient.type == "item" and ingredient.name == raw_item then uses_raw = true; break end
        end
        if uses_raw then
          for _, product in ipairs(recipe.products or {}) do
            if product.type == "item" then found[product.name] = true end
          end
        end
      end
    end
  end
  local list = {}
  for item in pairs(found) do list[#list + 1] = item end
  table.sort(list)
  return list
end

local function choose_output_product(player, source)
  local state = storage.local_gui[player.index]
  local products = output_products(source, state.pending_full and state.pending_full.product)
  if #products == 0 then error("无法识别该设备的成品；请先设置配方或等待它生产出一个成品") end
  if #products == 1 then select_output_destination(player, source, products[1]); return end
  close_output_picker(player)
  local frame = player.gui.center.add({ type = "frame", name = PREFIX .. "output_picker", caption = "选择要分类收纳的成品", direction = "vertical" })
  state.output_choices = { source = source, items = products }
  for i, item in ipairs(products) do
    frame.add({ type = "button", name = PREFIX .. "output_pick_" .. i, caption = prototypes.item[item].localised_name })
  end
  frame.add({ type = "button", name = PREFIX .. "output_close", caption = "取消" })
end

local function open_work_mode(player)
  close_work_mode(player)
  local frame = player.gui.center.add({
    type = "frame", name = PREFIX .. "work_mode",
    caption = "选择采集、生产与收纳方式", direction = "vertical",
  })
  frame.add({ type = "button", name = PREFIX .. "work_full", caption = "采集 → 生产 → 收纳（全流程）" })
  frame.add({ type = "button", name = PREFIX .. "work_both", caption = "只采集并投料" })
  frame.add({ type = "button", name = PREFIX .. "work_mine", caption = "只采集" })
  frame.add({ type = "button", name = PREFIX .. "work_supply", caption = "只生产投料" })
  frame.add({ type = "button", name = PREFIX .. "work_output", caption = "只收纳成品" })
  frame.add({ type = "button", name = PREFIX .. "work_close", caption = "取消" })
end

local function reusable_target(target, item)
  if not (target and target.valid) then return false end
  local accepted = false
  pcall(function() accepted = target.can_insert({ name = item, count = 1 }) end)
  return accepted
end

local function open_mining_destination(player, resource)
  close_mining_destination(player)
  local frame = player.gui.center.add({
    type = "frame",
    name = PREFIX .. "mining_destination",
    caption = "选择 " .. resource .. " 的产物去向",
    direction = "vertical",
  })
  frame.add({ type = "button", name = PREFIX .. "mine_carry", caption = "随身携带" })
  frame.add({ type = "button", name = PREFIX .. "mine_store", caption = "存入指定容器" })
  frame.add({ type = "button", name = PREFIX .. "mine_destination_close", caption = "取消" })
end

local BASIC_RESOURCES = {
  ["iron-ore"] = true, ["copper-ore"] = true, ["coal"] = true,
  ["stone"] = true, ["uranium-ore"] = true,
}

local function mining_product(proto)
  for _, product in ipairs(proto.mineable_properties.products or {}) do
    if product.type == "item" then return product.name end
  end
  return nil
end

local function open_mining_picker(player)
  close_mining_picker(player)
  local basic, other = {}, {}
  for name, proto in pairs(prototypes.entity) do
    if proto.type == "resource" and proto.mineable_properties.minable
      and not proto.mineable_properties.required_fluid then
      local product = mining_product(proto)
      if product then
        local entry = { resource = name, product = product, caption = proto.localised_name }
        local list = BASIC_RESOURCES[name] and basic or other
        list[#list + 1] = entry
      end
    end
  end
  local function by_name(a, b) return a.resource < b.resource end
  table.sort(basic, by_name)
  table.sort(other, by_name)
  local frame = player.gui.center.add({ type = "frame", name = PREFIX .. "mining_picker", caption = "选择采集的矿物", direction = "vertical" })
  local scroll = frame.add({ type = "scroll-pane" })
  scroll.style.maximal_height = 500
  storage.local_gui[player.index] = storage.local_gui[player.index] or {}
  local state = storage.local_gui[player.index]
  state.mining_choices = {}
  local function add_group(title, list)
    if #list == 0 then return end
    scroll.add({ type = "label", caption = title })
    for _, entry in ipairs(list) do
      state.mining_choices[#state.mining_choices + 1] = entry
      scroll.add({
        type = "button",
        name = PREFIX .. "mine_pick_" .. #state.mining_choices,
        caption = { "", entry.caption, "（", entry.product, "）" },
      })
    end
  end
  add_group("基础矿物", basic)
  add_group("其他可采资源", other)
  frame.add({ type = "button", name = PREFIX .. "mine_close", caption = "取消" })
end

local function open_blueprint_picker(player)
  close_blueprint_picker(player)
  local result = blueprint.list({ player = player.name })
  if #result.blueprints == 0 then error("没有找到蓝图；请把蓝图或蓝图书放在玩家/助手物品栏中") end
  local frame = player.gui.center.add({ type = "frame", name = PREFIX .. "blueprint_picker", caption = "选择要建造的蓝图", direction = "vertical" })
  local scroll = frame.add({ type = "scroll-pane", name = PREFIX .. "blueprint_scroll" })
  scroll.style.maximal_height = 500
  storage.local_gui[player.index] = storage.local_gui[player.index] or {}
  local state = storage.local_gui[player.index]
  state.blueprints = {}
  for i, bp in ipairs(result.blueprints) do
    if i > 40 then break end
    if bp.label and bp.label ~= "" then
      state.blueprints[#state.blueprints + 1] = { label = bp.label, book = bp.book }
      scroll.add({
        type = "button",
        name = PREFIX .. "bp_pick_" .. #state.blueprints,
        caption = bp.label .. "（" .. tostring(bp.entity_count or 0) .. " 个建筑）",
      })
    end
  end
  if #state.blueprints == 0 then
    frame.destroy()
    error("找到的蓝图都没有名称；请先给蓝图命名")
  end
  frame.add({ type = "button", name = PREFIX .. "bp_close", caption = "取消" })
end

local function ensure_companion(player)
  companion.set_context(nil)
  local c = companion.get()
  if not c then
    companion.spawn({ near_player = player.name })
    c = companion.get()
  end
  return c
end

local function refresh_target_selector(player)
  local panel = player.gui.left[PREFIX .. "panel"]
  local selector = panel and panel[PREFIX .. "target"]
  if not (selector and selector.valid) then return end
  storage.local_gui[player.index] = storage.local_gui[player.index] or {}
  local state = storage.local_gui[player.index]
  local items = { "全部助手" }
  local selected = 1
  for _, name in ipairs(companion.names()) do
    items[#items + 1] = name
    if state.command_target == name then selected = #items end
  end
  if selected == 1 then state.command_target = nil end
  selector.items = items
  selector.selected_index = selected
end

command_names = function(player)
  ensure_companion(player)
  storage.local_gui[player.index] = storage.local_gui[player.index] or {}
  local wanted = storage.local_gui[player.index].command_target
  if wanted and companion.get(wanted) then return { wanted } end
  return companion.names()
end

local function command_label(player)
  local state = storage.local_gui[player.index]
  return (state and state.command_target) or "全部助手"
end

local function configured_count(player, field, fallback, maximum)
  local panel = player.gui.left[PREFIX .. "panel"]
  local controls = panel and panel[PREFIX .. "supply_controls"]
  local input = controls and controls[PREFIX .. field]
  local value = math.floor(tonumber(input and input.text) or fallback)
  return math.max(1, math.min(value, maximum))
end

local function order(player, task, name)
  ensure_companion(player)
  companion.set_context(name)
  tasks.enqueue({ task = task, replace = true, background = true })
  companion.set_context(nil)
end

local function order_all(player, make_task)
  for _, name in ipairs(command_names(player)) do
    companion.set_context(name)
    local c = companion.get(name)
    tasks.enqueue({ task = make_task(c, name), replace = true, background = true })
  end
  companion.set_context(nil)
end

local WEAPON_PAIRS = {
  { "combat-shotgun", "piercing-shotgun-shell" }, { "combat-shotgun", "shotgun-shell" },
  { "shotgun", "piercing-shotgun-shell" }, { "shotgun", "shotgun-shell" },
  { "submachine-gun", "uranium-rounds-magazine" }, { "submachine-gun", "piercing-rounds-magazine" },
  { "submachine-gun", "firearm-magazine" }, { "pistol", "uranium-rounds-magazine" },
  { "pistol", "piercing-rounds-magazine" }, { "pistol", "firearm-magazine" },
  { "rocket-launcher", "explosive-rocket" }, { "rocket-launcher", "rocket" },
  { "flamethrower", "flamethrower-ammo" },
}

local function take_from_nearby_chests(c, item_name, wanted)
  local moved = 0
  local types = { "container", "logistic-container" }
  for _, box in ipairs(c.surface.find_entities_filtered({ position = c.position, radius = c.reach_distance, force = c.force, type = types })) do
    if moved >= wanted then break end
    local chest = box.get_inventory(defines.inventory.chest)
    if chest then
      local available = chest.get_item_count(item_name)
      if available > 0 then
        local inserted = c.get_main_inventory().insert({ name = item_name, count = math.min(available, wanted - moved) })
        if inserted > 0 then
          chest.remove({ name = item_name, count = inserted })
          moved = moved + inserted
        end
      end
    end
  end
  return moved
end

local function add_companion(player)
  local names = companion.names()
  if #names >= 4 then error("最多只能有 4 个 AI 助手") end
  local name = #names == 0 and companion.DEFAULT or ("AI" .. tostring(#names + 1))
  companion.set_context(name)
  companion.spawn({ name = name, near_player = player.name })
  companion.set_context(nil)
  return name
end

local function remove_companion(player)
  local names = companion.names()
  if #names == 0 then error("当前没有 AI 助手") end
  local state = storage.local_gui[player.index]
  local name = state and state.command_target
  if not name or not companion.get(name) then name = names[#names] end
  tasks.cancel({ all = true, companion = name })
  companion.remove(name)
  companion.set_context(nil)
  return name
end

local function nearest_resource(c)
  local best, best_d
  for _, e in ipairs(c.surface.find_entities_filtered({ position = c.position, radius = 80, type = "resource" })) do
    if e.valid and e.prototype.mineable_properties.minable then
      local dx, dy = e.position.x - c.position.x, e.position.y - c.position.y
      local d = dx * dx + dy * dy
      if not best or d < best_d then best, best_d = e, d end
    end
  end
  return best
end

local function equip_carried_weapon(c)
  local inv = c.get_main_inventory()
  for _, pair in ipairs(WEAPON_PAIRS) do
    if inv.get_item_count(pair[1]) == 0 then take_from_nearby_chests(c, pair[1], 1) end
    if inv.get_item_count(pair[1]) > 0 then
      if inv.get_item_count(pair[2]) == 0 then take_from_nearby_chests(c, pair[2], 100) end
    end
    if inv.get_item_count(pair[1]) > 0 and inv.get_item_count(pair[2]) > 0 then
      equipment.equip({ gun = pair[1], ammo = pair[2] })
      return pair[1]
    end
  end
  error("助手背包里没有可配套使用的武器和弹药")
end

local function open_supply_picker(player)
  close_supply_picker(player)
  local totals, seen_boxes = {}, {}
  local function add_inventory(inv)
    if not inv then return end
    for _, item in ipairs(inv.get_contents()) do
      local proto = prototypes.item[item.name]
      if proto and proto.type == "item" then
        totals[item.name] = (totals[item.name] or 0) + item.count
      end
    end
  end
  for _, who in ipairs(command_names(player)) do
    local c = companion.get(who)
    if c then
      add_inventory(c.get_main_inventory())
      for _, box in ipairs(c.surface.find_entities_filtered({
        position = c.position,
        radius = c.reach_distance,
        force = c.force,
        type = { "container", "logistic-container" },
      })) do
        local id = box.unit_number or tostring(box.position.x) .. ":" .. tostring(box.position.y)
        if not seen_boxes[id] then
          seen_boxes[id] = true
          add_inventory(box.get_inventory(defines.inventory.chest))
        end
      end
    end
  end
  local names = {}
  for name, count in pairs(totals) do if count > 0 then names[#names + 1] = name end end
  table.sort(names)
  if #names == 0 then error("所选助手及其伸手可及的箱子中没有可投放的原材料") end
  local frame = player.gui.center.add({ type = "frame", name = PREFIX .. "supply_picker", caption = "选择生产原材料（一组）", direction = "vertical" })
  local scroll = frame.add({ type = "scroll-pane" })
  scroll.style.maximal_height = 500
  storage.local_gui[player.index] = storage.local_gui[player.index] or {}
  local state = storage.local_gui[player.index]
  state.supply_choices = {}
  for _, name in ipairs(names) do
    state.supply_choices[#state.supply_choices + 1] = name
    scroll.add({
      type = "button",
      name = PREFIX .. "supply_pick_" .. #state.supply_choices,
      caption = { "", prototypes.item[name].localised_name, "（可用 ", totals[name], "）" },
    })
  end
  frame.add({ type = "button", name = PREFIX .. "supply_close", caption = "取消" })
end

local function start_mining_jobs(player, pending, target)
  local assigned = 0
  for _, who in ipairs(pending.companions or {}) do
    if companion.get(who) then
      companion.set_context(who)
      tasks.enqueue({
        task = { type = "mine", resource = pending.resource, count = 200 },
        replace = true,
        background = true,
        quiet = target ~= nil,
      })
      if target then
        tasks.enqueue({
          task = {
            type = "insert",
            target = { x = target.position.x, y = target.position.y },
            items = { [pending.product] = 1000000 },
          },
          replace = false,
          background = true,
        })
      end
      assigned = assigned + 1
    end
  end
  companion.set_context(nil)
  storage.local_gui[player.index].pending_mining = nil
  if target then
    status(player, string.format("已命令 %d 个助手采集 %s，完成后送往所选箱子", assigned, pending.resource))
  else
    status(player, string.format("已命令 %d 个助手采集 %s，产物保留在各自背包", assigned, pending.resource))
  end
end

local function start_combined_jobs(player, pending, target)
  local assigned = 0
  for _, who in ipairs(pending.companions or {}) do
    if companion.get(who) then
      companion.set_context(who)
      tasks.enqueue({
        task = {
          type = "mine_supply",
          resource = pending.resource,
          product = pending.product,
          harvest_count = pending.harvest_count,
          supply_count = pending.supply_count,
          target = { x = target.position.x, y = target.position.y },
        },
        replace = true,
        background = true,
      })
      assigned = assigned + 1
    end
  end
  companion.set_context(nil)
  local state = storage.local_gui[player.index]
  state.last_combined_targets = state.last_combined_targets or {}
  state.last_combined_targets[pending.product] = target
  state.pending_combined = nil
  player.clear_cursor()
  status(player, string.format(
    "已命令 %d 个助手循环工作：每采集 %d 次 %s，向目标投入最多 %d 个",
    assigned, pending.harvest_count, pending.resource, pending.supply_count))
end

function M.initialize()
  storage.local_gui = storage.local_gui or {}
  for _, player in pairs(game.players) do
    local panel = player.gui.left[PREFIX .. "panel"]
    if panel and panel.valid then panel.destroy() end
    local toggle = player.gui.top[PREFIX .. "toggle"]
    if toggle and toggle.valid then toggle.destroy() end
    make_gui(player)
    refresh_target_selector(player)
  end
end

function M.on_player_created(event)
  local player = game.get_player(event.player_index)
  if player then make_gui(player) end
end

function M.on_gui_selection_changed(event)
  local player = game.get_player(event.player_index)
  local element = event.element
  if not player or not element or not element.valid or element.name ~= PREFIX .. "target" then return end
  storage.local_gui[player.index] = storage.local_gui[player.index] or {}
  local selected = element.get_item(element.selected_index)
  storage.local_gui[player.index].command_target = selected ~= "全部助手" and selected or nil
  status(player, "当前指令对象：" .. selected)
end

function M.on_gui_text_changed(event)
  local element = event.element
  if not (element and element.valid and element.name == PREFIX .. "fuel_count") then return end
  local value = math.floor(tonumber(element.text) or 10)
  storage.autonomy_fuel_target = math.max(1, math.min(value, 1000))
end

function M.on_gui_click(event)
  local player = game.get_player(event.player_index)
  local element = event.element
  if not player or not element or not element.valid then return end
  local name = element.name
  if name == PREFIX .. "toggle" then
    local panel = player.gui.left[PREFIX .. "panel"]
    panel.visible = not panel.visible
    return
  end
  if name == PREFIX .. "bp_close" then
    close_blueprint_picker(player)
    return
  end
  if name == PREFIX .. "blueprint_materials_close" then
    close_blueprint_materials(player)
    return
  end
  if name == PREFIX .. "mine_close" then
    close_mining_picker(player)
    return
  end
  if name == PREFIX .. "mine_destination_close" then
    close_mining_destination(player)
    return
  end
  if name == PREFIX .. "supply_close" then
    close_supply_picker(player)
    return
  end
  if name == PREFIX .. "work_close" then
    close_work_mode(player)
    return
  end
  if name == PREFIX .. "output_close" then
    close_output_picker(player)
    return
  end
  local ok, err = pcall(function()
    local output_pick = string.match(name, "^" .. PREFIX .. "output_pick_(%d+)$")
    if output_pick then
      local state = storage.local_gui[player.index]
      local choices = state and state.output_choices
      local item = choices and choices.items[tonumber(output_pick)]
      if not (choices and choices.source and choices.source.valid and item) then
        error("成品选择已失效，请重新选择生产设备")
      end
      select_output_destination(player, choices.source, item)
      return
    end
    local pick = string.match(name, "^" .. PREFIX .. "bp_pick_(%d+)$")
    if pick then
      local state = storage.local_gui[player.index]
      local chosen = state and state.blueprints and state.blueprints[tonumber(pick)]
      if not chosen then error("蓝图选择已失效，请重新打开列表") end
      close_blueprint_picker(player)
      local info = blueprint.put_on_cursor({ label = chosen.label, book = chosen.book, player = player.name })
      state.native_blueprint_active = true
      state.native_blueprint_ghosts = {}
      show_blueprint_materials(player, info)
      status(player, "蓝图已拿在手上；移动鼠标查看虚影，旋转后点击放置")
      return
    end
    local mine_pick = string.match(name, "^" .. PREFIX .. "mine_pick_(%d+)$")
    if mine_pick then
      local state = storage.local_gui[player.index]
      local chosen = state and state.mining_choices and state.mining_choices[tonumber(mine_pick)]
      if not chosen then error("矿物选择已失效，请重新打开列表") end
      local pending = {
        resource = chosen.resource,
        product = chosen.product,
        companions = command_names(player),
      }
      close_mining_picker(player)
      if state.work_mode == "both" then
        pending.harvest_count = configured_count(player, "harvest_count", 50, 200)
        pending.supply_count = configured_count(player, "supply_count", 50, 1000)
        state.pending_combined = pending
        local remembered = state.last_combined_targets and state.last_combined_targets[pending.product]
        if reusable_target(remembered, pending.product) then
          start_combined_jobs(player, pending, remembered)
        else
          player.clear_cursor()
          player.cursor_stack.set_stack({ name = "agentic-local-production-target-tool", count = 1 })
          status(player, "请框选接收 " .. pending.product .. " 的生产设备或容器；以后会自动复用直到装满")
        end
      elseif state.work_mode == "full" then
        pending.harvest_count = configured_count(player, "harvest_count", 50, 200)
        pending.supply_count = configured_count(player, "supply_count", 50, 1000)
        state.pending_full = pending
        player.clear_cursor()
        player.cursor_stack.set_stack({ name = "agentic-local-production-target-tool", count = 1 })
        status(player, "已选择 " .. chosen.resource .. "；请框选使用该原料的生产设备")
      else
        state.pending_mining = pending
        open_mining_destination(player, chosen.resource)
      end
      return
    end
    if name == PREFIX .. "mine_carry" then
      local state = storage.local_gui[player.index]
      local pending = state and state.pending_mining
      if not pending then error("采矿选择已失效，请重新选择") end
      close_mining_destination(player)
      start_mining_jobs(player, pending, nil)
      return
    elseif name == PREFIX .. "mine_store" then
      local state = storage.local_gui[player.index]
      if not (state and state.pending_mining) then error("采矿选择已失效，请重新选择") end
      close_mining_destination(player)
      local remembered = state.last_mining_target
      if reusable_target(remembered, state.pending_mining.product) then
        start_mining_jobs(player, state.pending_mining, remembered)
      else
        player.clear_cursor()
        player.cursor_stack.set_stack({ name = "agentic-local-mine-container-tool", count = 1 })
        status(player, "请框选一个用于存放矿物的己方箱子；以后会自动复用直到装满")
      end
      return
    end
    local supply_pick = string.match(name, "^" .. PREFIX .. "supply_pick_(%d+)$")
    if supply_pick then
      local state = storage.local_gui[player.index]
      local item = state and state.supply_choices and state.supply_choices[tonumber(supply_pick)]
      if not item then error("原材料选择已失效，请重新打开列表") end
      state.pending_supply = {
        item = item,
        count = configured_count(player, "supply_count", 50, 1000),
        companions = command_names(player),
      }
      close_supply_picker(player)
      player.clear_cursor()
      player.cursor_stack.set_stack({ name = "agentic-local-production-target-tool", count = 1 })
      status(player, "已选择 " .. item .. "；请框选熔炉、生产设备或接收容器")
      return
    end
    if name == PREFIX .. "work_full" then
      storage.local_gui[player.index].work_mode = "full"
      close_work_mode(player)
      open_mining_picker(player)
      return
    elseif name == PREFIX .. "work_both" then
      storage.local_gui[player.index].work_mode = "both"
      close_work_mode(player)
      open_mining_picker(player)
      return
    elseif name == PREFIX .. "work_mine" then
      storage.local_gui[player.index].work_mode = "mine"
      close_work_mode(player)
      open_mining_picker(player)
      return
    elseif name == PREFIX .. "work_supply" then
      storage.local_gui[player.index].work_mode = "supply"
      close_work_mode(player)
      open_supply_picker(player)
      return
    elseif name == PREFIX .. "work_output" then
      close_work_mode(player)
      player.clear_cursor()
      player.cursor_stack.set_stack({ name = "agentic-local-output-source-tool", count = 1 })
      status(player, "请框选要自动取出成品的熔炉或生产设备")
      return
    elseif name == PREFIX .. "spawn" then
      local added = add_companion(player)
      refresh_target_selector(player)
      status(player, added .. " 已生成；当前共有 " .. #companion.names() .. " 个 AI")
    elseif name == PREFIX .. "remove" then
      local removed = remove_companion(player)
      refresh_target_selector(player)
      status(player, removed .. " 已移除；它的物品已掉落在原地")
    elseif name == PREFIX .. "equip" then
      ensure_companion(player)
      local equipped = 0
      for _, who in ipairs(command_names(player)) do
        companion.set_context(who)
        local good = pcall(equip_carried_weapon, companion.get(who))
        if good then equipped = equipped + 1 end
      end
      companion.set_context(nil)
      status(player, "已为 " .. equipped .. " 个所选助手装备武器弹药")
    elseif name == PREFIX .. "refuel" then
      local top_up = configured_count(player, "fuel_count", 10, 1000)
      order_all(player, function(c)
        return {
          type = "keep_fueled",
          center = { x = c.position.x, y = c.position.y },
          radius = 256,
          top_up_count = top_up,
        }
      end)
      status(player, "正在补齐附近设备；可从助手背包或附近己方箱子取燃料")
    elseif name == PREFIX .. "follow" then
      order_all(player, function() return { type = "follow_player", player = player.name, distance = 3 } end)
      status(player, command_label(player) .. " 正在跟随你")
    elseif name == PREFIX .. "hold" then
      order_all(player, function(c)
        return { type = "defend_area", center = { x = c.position.x, y = c.position.y }, radius = 24 }
      end)
      status(player, command_label(player) .. " 正在原地镇守")
    elseif name == PREFIX .. "patrol" then
      order_all(player, function() return { type = "patrol", radius = 12 } end)
      status(player, command_label(player) .. " 正在周边巡逻")
    elseif name == PREFIX .. "attack" then
      order_all(player, function(c)
        return { type = "fight", target = { x = c.position.x, y = c.position.y }, radius = 40 }
      end)
      status(player, command_label(player) .. " 正在清理附近敌人")
    elseif name == PREFIX .. "stop" then
      local selected = command_names(player)
      for _, who in ipairs(selected) do tasks.cancel({ all = true, companion = who }) end
      status(player, "已停止 " .. command_label(player))
    elseif name == PREFIX .. "build" then
      ensure_companion(player)
      player.clear_cursor()
      player.cursor_stack.set_stack({ name = "agentic-local-build-tool", count = 1 })
      status(player, "请框选蓝图幽灵；材料从助手背包消耗")
    elseif name == PREFIX .. "demolish" then
      ensure_companion(player)
      player.clear_cursor()
      player.cursor_stack.set_stack({ name = "agentic-local-demolish-tool", count = 1 })
      status(player, "请框选己方建筑、树木、岩石或残骸")
    elseif name == PREFIX .. "mine_supply" then
      ensure_companion(player)
      open_work_mode(player)
    elseif name == PREFIX .. "blueprints" then
      ensure_companion(player)
      open_blueprint_picker(player)
    end
  end)
  companion.set_context(nil)
  if not ok then status(player, "命令失败：" .. tostring(err)) end
end

local function queue_selection(player, entities, mode)
  ensure_companion(player)
  local names = command_names(player)
  local buckets = {}
  for i = 1, #names do buckets[i] = {} end
  local accepted = 0
  for _, entity in ipairs(entities) do
    if accepted >= 800 then break end
    local valid = entity.valid
    if mode == "build" then
      valid = valid and entity.type == "entity-ghost" and entity.force == player.force
    else
      valid = valid and entity.type ~= "character" and entity.minable
        and (entity.force == player.force or entity.force == game.forces.neutral)
    end
    if valid then
      accepted = accepted + 1
      local bucket = (accepted - 1) % #names + 1
      buckets[bucket][#buckets[bucket] + 1] = entity
    end
  end
  if accepted == 0 then
    status(player, "框选范围内没有可处理的目标")
    return
  end
  local workers = 0
  for i, targets in ipairs(buckets) do
    if #targets > 0 then
      companion.set_context(names[i])
      tasks.enqueue({
        task = { type = "local_selection", mode = mode, entities = targets },
        replace = true,
        background = true,
      })
      workers = workers + 1
    end
  end
  companion.set_context(nil)
  local verb = mode == "build" and "建造" or "拆除"
  status(player, string.format("已把 %d 个目标分配给 %d 个助手；它们会逐个走近并%s", accepted, workers, verb))
end

function M.on_selected_area(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  if event.item == "agentic-local-build-tool" then
    queue_selection(player, event.entities, "build")
  elseif event.item == "agentic-local-demolish-tool" then
    queue_selection(player, event.entities, "demolish")
  elseif event.item == "agentic-local-blueprint-anchor-tool" then
    local state = storage.local_gui[player.index]
    local chosen = state and state.pending_blueprint
    if not chosen then
      status(player, "没有待建造的蓝图，请重新选择")
      return
    end
    local area = event.area
    local anchor = area and area.left_top
    if not anchor then
      status(player, "没有取得施工位置，请重试")
      return
    end
    local builders = command_names(player)
    order(player, {
      type = "build_blueprint",
      label = chosen.label,
      book = chosen.book,
      player = player.name,
      anchor = { x = anchor.x, y = anchor.y },
      auto_craft = false,
    }, builders[1])
    state.pending_blueprint = nil
    player.clear_cursor()
    status(player, "已开始建造 " .. chosen.label .. "；缺少的材料会从伸手可及的己方箱子获取")
  elseif event.item == "agentic-local-mine-container-tool" then
    local state = storage.local_gui[player.index]
    local pending = state and state.pending_mining
    if not pending then
      status(player, "没有待执行的采矿选择，请重新选择矿物")
      return
    end
    local target
    for _, entity in ipairs(event.entities) do
      if entity.valid and entity.force == player.force
        and (entity.type == "container" or entity.type == "logistic-container") then
        target = entity
        break
      end
    end
    if not target then
      status(player, "框选范围内没有己方箱子，请重新选择")
      return
    end
    state.last_mining_target = target
    start_mining_jobs(player, pending, target)
    player.clear_cursor()
  elseif event.item == "agentic-local-production-target-tool" then
    local state = storage.local_gui[player.index]
    local combined = state and state.pending_combined
    local full = state and state.pending_full
    local pending = state and state.pending_supply
    if not pending and not combined and not full then
      status(player, "没有待执行的生产投料任务")
      return
    end
    local target
    for _, entity in ipairs(event.entities) do
      if entity.valid and entity.force == player.force and entity.type ~= "character" then
        target = entity
        break
      end
    end
    if not target then
      status(player, "框选范围内没有己方生产设备或容器")
      return
    end
    if full then
      local output_inv
      pcall(function() output_inv = target.get_output_inventory() end)
      if not output_inv then status(player, "所选目标不是可生产并输出成品的设备"); return end
      full.machine = { x = target.position.x, y = target.position.y }
      full.source_entity = target
      local ok, err = pcall(choose_output_product, player, target)
      if not ok then status(player, "命令失败：" .. tostring(err)) end
      return
    end
    if combined then
      if not reusable_target(target, combined.product) then
        status(player, "所选设备或容器不能接收 " .. combined.product .. "，请重新选择")
        return
      end
      start_combined_jobs(player, combined, target)
      return
    end
    local assigned = 0
    for _, who in ipairs(pending.companions or {}) do
      if companion.get(who) then
        companion.set_context(who)
        tasks.enqueue({
          task = {
            type = "supply_input",
            item = pending.item,
            count = pending.count,
            target = { x = target.position.x, y = target.position.y },
          },
          replace = true,
          background = true,
        })
        assigned = assigned + 1
      end
    end
    companion.set_context(nil)
    state.pending_supply = nil
    player.clear_cursor()
    status(player, string.format("已命令 %d 个助手向 %s 运送 %s", assigned, target.name, pending.item))
  elseif event.item == "agentic-local-output-source-tool" then
    local source
    for _, entity in ipairs(event.entities) do
      local inv
      if entity.valid and entity.force == player.force then
        pcall(function() inv = entity.get_output_inventory() end)
      end
      if inv then source = entity; break end
    end
    if not source then
      status(player, "框选范围内没有带成品库存的己方生产设备")
      return
    end
    local ok, err = pcall(choose_output_product, player, source)
    if not ok then status(player, "命令失败：" .. tostring(err)) end
  elseif event.item == "agentic-local-output-destination-tool" then
    local state = storage.local_gui[player.index]
    local pending = state and state.pending_output
    if not (pending and pending.source and pending.source.valid) then
      status(player, "成品来源选择已失效，请重新选择")
      return
    end
    local destination
    for _, entity in ipairs(event.entities) do
      if entity.valid and entity.force == player.force
        and (entity.type == "container" or entity.type == "logistic-container") then
        destination = entity; break
      end
    end
    if not destination then
      status(player, "框选范围内没有己方箱子")
      return
    end
    local accepts = false
    pcall(function() accepts = destination.can_insert({ name = pending.item, count = 1 }) end)
    if not accepts then
      status(player, "该箱子已满或不能接收 " .. pending.item .. "，请重新选择")
      return
    end
    local key = tostring(pending.source.unit_number or pending.source.position.x .. ":" .. pending.source.position.y)
      .. ":" .. pending.item
    storage.output_routes[key] = {
      source = pending.source, destination = destination, item = pending.item,
    }
    local assigned = 0
    for _, who in ipairs(pending.companions or {}) do
      if companion.get(who) then
        companion.set_context(who)
        local task
        if pending.full then
          task = {
            type = "production_chain",
            resource = pending.full.resource,
            raw_item = pending.full.product,
            harvest_count = pending.full.harvest_count,
            supply_count = pending.full.supply_count,
            collect_count = pending.full.supply_count,
            machine = pending.full.machine,
            source_entity = pending.source,
            output_item = pending.item,
            destination = { x = destination.position.x, y = destination.position.y },
          }
        else
          task = { type = "output_sort", batch = configured_count(player, "supply_count", 50, 1000) }
        end
        tasks.enqueue({ task = task, replace = true, background = true })
        assigned = assigned + 1
      end
    end
    companion.set_context(nil)
    state.pending_output = nil
    state.pending_full = nil
    player.clear_cursor()
    status(player, pending.full
      and string.format("已安排 %d 个助手循环执行采集、生产和分类收纳", assigned)
      or string.format("已记录 %s → 所选箱子，并安排 %d 个助手自动收纳", pending.item, assigned))
  end
end

-- Native blueprint placement creates one entity-ghost event per building.
-- Gather all ghosts from the same placement tick, then hand the whole group
-- to the physical builders on the following tick.
function M.on_built_entity(event)
  local player = event.player_index and game.get_player(event.player_index)
  local entity = event.entity or event.created_entity
  if not (player and entity and entity.valid and entity.type == "entity-ghost") then return end
  local state = storage.local_gui[player.index]
  if not (state and state.native_blueprint_active) then return end
  state.native_blueprint_ghosts = state.native_blueprint_ghosts or {}
  state.native_blueprint_ghosts[#state.native_blueprint_ghosts + 1] = entity
  state.native_blueprint_queue_tick = game.tick + 1
end

function M.on_tick()
  for player_index, state in pairs(storage.local_gui or {}) do
    if state.native_blueprint_queue_tick and game.tick >= state.native_blueprint_queue_tick then
      local player = game.get_player(player_index)
      local ghosts = state.native_blueprint_ghosts or {}
      state.native_blueprint_queue_tick = nil
      state.native_blueprint_ghosts = {}
      if player and #ghosts > 0 then queue_selection(player, ghosts, "build") end
    end
  end
end

return M
