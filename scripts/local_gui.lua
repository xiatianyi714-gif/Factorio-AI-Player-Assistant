local companion = require("scripts.companion")
local tasks = require("scripts.tasks")
local equipment = require("scripts.equipment")
local blueprint = require("scripts.blueprint")

local M = {}
local PREFIX = "agentic_local_"
local command_names

local function english()
  return storage.local_language == "en"
end

local function show_main_section(player, selected)
  local panel = player.gui.left[PREFIX .. "panel"]
  if not (panel and panel.valid) then return end
  for _, key in ipairs({ "common", "work", "manage", "live" }) do
    local section = panel[PREFIX .. key .. "_section"]
    if section and section.valid then section.visible = key == selected end
  end
  storage.local_gui[player.index] = storage.local_gui[player.index] or {}
  storage.local_gui[player.index].main_section = selected
end

local function T(zh, en)
  return english() and en or zh
end

local function command_speech(text)
  if english() then
    if string.find(text, "following", 1, true) then return "Follow me!" end
    if string.find(text, "holding", 1, true) then return "Hold this position!" end
    if string.find(text, "patrolling", 1, true) then return "Patrol the area!" end
    if string.find(text, "clearing", 1, true) then return "Clear nearby enemies!" end
    if string.find(text, "Refueling", 1, true) then return "Check the machines and refuel them!" end
    if string.find(text, "repairing", 1, true) then return "Find and repair damaged machines!" end
    if string.find(text, "mine", 1, true) then return "Collect the selected resources!" end
    if string.find(text, "Stopped", 1, true) then return "Stop the current orders!" end
    if string.find(text, "ghosts", 1, true) then return "Start construction!" end
    if string.find(text, "structures", 1, true) then return "Deconstruct these targets!" end
    if string.find(text, "Equipped", 1, true) then return "Check and equip weapons!" end
    return nil
  end
  if string.find(text, "跟随", 1, true) then return "跟着我！" end
  if string.find(text, "镇守", 1, true) then return "守住这里！" end
  if string.find(text, "巡逻", 1, true) then return "去附近巡逻！" end
  if string.find(text, "清理附近敌人", 1, true) then return "清理附近的敌人！" end
  if string.find(text, "补齐", 1, true) or string.find(text, "补充燃料", 1, true) then
    return "去检查设备并补充燃料！"
  end
  if string.find(text, "维修", 1, true) or string.find(text, "修理", 1, true) then
    return "去检查并修好受损设备！"
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
    player.print({ "", T("[本地助手] ", "[Local Companion] "), text })
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
    player.gui.top.add({ type = "button", name = PREFIX .. "toggle", caption = T("助手命令", "Companion Commands"), tooltip = T("纯本地控制，不使用 AI 或 Token", "Fully local control; no AI or tokens") })
  end
  if player.gui.left[PREFIX .. "panel"] then return end
  local frame = player.gui.left.add({ type = "frame", name = PREFIX .. "panel", caption = T("战斗施工助手", "Combat & Construction Companions"), direction = "vertical" })
  frame.visible = false
  frame.add({ type = "button", name = PREFIX .. "language", caption = T("语言：中文（点击切换英文）", "Language: English (click for Chinese)") })
  frame.add({ type = "label", caption = T("指令对象", "Command target") })
  local target_items = { T("全部助手", "All companions") }
  for _, name in ipairs(companion.names()) do target_items[#target_items + 1] = name end
  frame.add({ type = "drop-down", name = PREFIX .. "target", items = target_items, selected_index = 1 })
  local tabs = frame.add({ type = "table", column_count = 4 })
  tabs.add({ type = "button", name = PREFIX .. "section_common", caption = T("常用", "Orders") })
  tabs.add({ type = "button", name = PREFIX .. "section_work", caption = T("工作", "Work") })
  tabs.add({ type = "button", name = PREFIX .. "section_manage", caption = T("管理", "Manage") })
  tabs.add({ type = "button", name = PREFIX .. "section_live", caption = T("状态", "Status") })

  local common = frame.add({ type = "flow", name = PREFIX .. "common_section", direction = "vertical" })
  local quick = common.add({ type = "table", column_count = 2 })
  quick.add({ type = "button", name = PREFIX .. "follow", caption = T("跟随我", "Follow me") })
  quick.add({ type = "button", name = PREFIX .. "hold", caption = T("原地镇守", "Hold position") })
  quick.add({ type = "button", name = PREFIX .. "patrol", caption = T("巡逻", "Patrol") })
  quick.add({ type = "button", name = PREFIX .. "patrol_saved", caption = T("使用保存路线", "Use saved route") })
  quick.add({ type = "button", name = PREFIX .. "attack", caption = T("清理敌人", "Clear enemies") })
  quick.add({ type = "button", name = PREFIX .. "stop", caption = T("停止命令", "Stop orders") })
  quick.add({ type = "button", name = PREFIX .. "refuel", caption = T("补齐燃料", "Refuel machines") })
  quick.add({ type = "button", name = PREFIX .. "repair", caption = T("主动维修", "Repair machines") })

  local work = frame.add({ type = "flow", name = PREFIX .. "work_section", direction = "vertical" })
  work.visible = false
  work.add({ type = "button", name = PREFIX .. "priorities", caption = T("各助手工作优先级与范围", "Companion priorities and range") })
  local supply = work.add({ type = "table", name = PREFIX .. "supply_controls", column_count = 2 })
  supply.add({ type = "label", caption = T("设备燃料目标数量", "Target fuel count") })
  supply.add({ type = "textfield", name = PREFIX .. "fuel_count", text = tostring(storage.autonomy_fuel_target or 10), numeric = true, allow_decimal = false, allow_negative = false })
  supply.add({ type = "label", caption = T("炮塔目标弹药数量", "Target turret ammunition") })
  supply.add({ type = "textfield", name = PREFIX .. "turret_ammo_count", text = tostring(storage.autonomy_turret_ammo_target or 10), numeric = true, allow_decimal = false, allow_negative = false })
  supply.add({ type = "label", caption = T("每次投入数量", "Input amount per trip") })
  supply.add({ type = "textfield", name = PREFIX .. "supply_count", text = "50", numeric = true, allow_decimal = false, allow_negative = false })
  supply.add({ type = "label", caption = T("每采集多少去投", "Harvest amount before feeding") })
  supply.add({ type = "textfield", name = PREFIX .. "harvest_count", text = "50", numeric = true, allow_decimal = false, allow_negative = false })
  local build = work.add({ type = "table", column_count = 2 })
  build.add({ type = "button", name = PREFIX .. "patrol_custom", caption = T("设置巡逻路线", "Set patrol route") })
  build.add({ type = "button", name = PREFIX .. "patrol_finish", caption = T("完成巡逻路线", "Finish patrol route") })
  build.add({ type = "button", name = PREFIX .. "build", caption = T("框选建造蓝图", "Build selected ghosts") })
  build.add({ type = "button", name = PREFIX .. "demolish", caption = T("框选拆除", "Deconstruct selection") })
  build.add({ type = "button", name = PREFIX .. "mine_supply", caption = T("采集·生产·收纳", "Mine · Produce · Store") })
  build.add({ type = "button", name = PREFIX .. "blueprints", caption = T("蓝图施工", "Blueprint construction") })

  local manage = frame.add({ type = "flow", name = PREFIX .. "manage_section", direction = "vertical" })
  manage.visible = false
  manage.add({ type = "label", caption = T("助手与装备", "Companions and equipment") })
  local manage_buttons = manage.add({ type = "table", column_count = 2 })
  manage_buttons.add({ type = "button", name = PREFIX .. "spawn", caption = T("增加 AI", "Add AI") })
  manage_buttons.add({ type = "button", name = PREFIX .. "remove", caption = T("减少 AI", "Remove AI") })
  manage_buttons.add({ type = "button", name = PREFIX .. "equip", caption = T("装备现有武器", "Equip weapons") })
  manage.add({ type = "label", caption = T("补给只使用助手背包或己方箱子的真实物品", "Supplies use only real items from companion inventories or friendly chests") })

  local live = frame.add({ type = "flow", name = PREFIX .. "live_section", direction = "vertical" })
  live.visible = false
  live.add({ type = "label", caption = T("助手实时状态", "Live companion status") })
  live.add({ type = "table", name = PREFIX .. "assistant_status", column_count = 2 })
  frame.add({ type = "label", name = PREFIX .. "status", caption = T("就绪", "Ready") })
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
    caption = info.label .. T("：施工材料", ": Construction Materials"), direction = "vertical",
  })
  frame.auto_center = true
  frame.add({ type = "label", caption = T("建筑虚影：", "Ghost entities: ") .. tostring(info.entity_count) .. T(" 个", "") })
  local table_gui = frame.add({ type = "table", column_count = 4 })
  table_gui.add({ type = "label", caption = T("材料", "Material") })
  table_gui.add({ type = "label", caption = T("需要", "Required") })
  table_gui.add({ type = "label", caption = T("助手现有", "Available") })
  table_gui.add({ type = "label", caption = T("缺少", "Missing") })
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
  frame.add({ type = "button", name = PREFIX .. "blueprint_materials_close", caption = T("关闭材料清单", "Close material list") })
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
  status(player, T("已选择成品 ", "Selected product ") .. item .. T("；请框选它对应的己方箱子", "; select its destination chest"))
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
  local frame = player.gui.center.add({ type = "frame", name = PREFIX .. "output_picker", caption = T("选择要分类收纳的成品", "Choose a product to sort") , direction = "vertical" })
  state.output_choices = { source = source, items = products }
  for i, item in ipairs(products) do
    frame.add({ type = "button", name = PREFIX .. "output_pick_" .. i, caption = prototypes.item[item].localised_name })
  end
  frame.add({ type = "button", name = PREFIX .. "output_close", caption = T("取消", "Cancel") })
end

local function open_work_mode(player)
  close_work_mode(player)
  local frame = player.gui.center.add({
    type = "frame", name = PREFIX .. "work_mode",
    caption = T("选择采集、生产与收纳方式", "Choose mining, production and storage mode"), direction = "vertical",
  })
  frame.add({ type = "button", name = PREFIX .. "work_full", caption = T("采集 → 生产 → 收纳（全流程）", "Mine → Produce → Store (full workflow)") })
  frame.add({ type = "button", name = PREFIX .. "work_both", caption = T("只采集并投料", "Mine and feed only") })
  frame.add({ type = "button", name = PREFIX .. "work_mine", caption = T("只采集", "Mining only") })
  frame.add({ type = "button", name = PREFIX .. "work_supply", caption = T("只生产投料", "Production feeding only") })
  frame.add({ type = "button", name = PREFIX .. "work_output", caption = T("只收纳成品", "Store outputs only") })
  frame.add({ type = "button", name = PREFIX .. "work_close", caption = T("取消", "Cancel") })
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
    caption = T("选择 ", "Choose destination for ") .. resource .. T(" 的产物去向", ""),
    direction = "vertical",
  })
  frame.add({ type = "button", name = PREFIX .. "mine_carry", caption = T("随身携带", "Keep in inventory") })
  frame.add({ type = "button", name = PREFIX .. "mine_store", caption = T("存入指定容器", "Store in selected chest") })
  frame.add({ type = "button", name = PREFIX .. "mine_destination_close", caption = T("取消", "Cancel") })
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
  local frame = player.gui.center.add({ type = "frame", name = PREFIX .. "mining_picker", caption = T("选择采集的矿物", "Choose a resource to mine"), direction = "vertical" })
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
  add_group(T("基础矿物", "Basic ores"), basic)
  add_group(T("其他可采资源", "Other resources"), other)
  frame.add({ type = "button", name = PREFIX .. "mine_close", caption = T("取消", "Cancel") })
end

local function open_blueprint_picker(player)
  close_blueprint_picker(player)
  local result = blueprint.list({ player = player.name })
  if #result.blueprints == 0 then error("没有找到蓝图；请把蓝图或蓝图书放在玩家/助手物品栏中") end
  local frame = player.gui.center.add({ type = "frame", name = PREFIX .. "blueprint_picker", caption = T("选择要建造的蓝图", "Choose a blueprint to build"), direction = "vertical" })
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
        caption = bp.label .. T("（", " (") .. tostring(bp.entity_count or 0) .. T(" 个建筑）", " entities)"),
      })
    end
  end
  if #state.blueprints == 0 then
    frame.destroy()
    error("找到的蓝图都没有名称；请先给蓝图命名")
  end
  frame.add({ type = "button", name = PREFIX .. "bp_close", caption = T("取消", "Cancel") })
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
  local items = { T("全部助手", "All companions") }
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
  return (state and state.command_target) or T("全部助手", "All companions")
end

local function configured_count(player, field, fallback, maximum)
  local panel = player.gui.left[PREFIX .. "panel"]
  local work = panel and panel[PREFIX .. "work_section"]
  local controls = work and work[PREFIX .. "supply_controls"]
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

local WORK_TYPES = {
  { key = "repair", zh = "维修", en = "Repair", default = 1 },
  { key = "refuel", zh = "补燃料", en = "Refuel", default = 2 },
  { key = "turret", zh = "炮塔补弹", en = "Turret ammo", default = 3 },
  { key = "smelt", zh = "生产投料", en = "Production", default = 4 },
  { key = "patrol", zh = "巡逻", en = "Patrol", default = 4 },
  { key = "mine", zh = "采矿", en = "Mining", default = 4 },
}

local TASK_NAMES = {
  walk_to = { "移动", "Moving" }, follow_player = { "跟随", "Following" },
  mine = { "采矿", "Mining" }, keep_fueled = { "补燃料", "Refueling" },
  keep_repaired = { "维修", "Repairing" }, defend_area = { "镇守", "Defending" },
  patrol = { "巡逻", "Patrolling" }, fight = { "战斗", "Fighting" },
  turret_supply = { "炮塔补弹", "Supplying turret" }, supply_input = { "生产投料", "Supplying production" },
  output_sort = { "收纳成品", "Storing output" }, production_chain = { "采集生产收纳", "Production chain" },
  build_blueprint = { "蓝图施工", "Building blueprint" }, local_selection = { "框选施工", "Selection work" },
  deconstruct = { "拆除", "Deconstructing" }, recover_death_items = { "取回遗物", "Recovering items" },
}

local function task_name(kind)
  local names = TASK_NAMES[kind]
  return names and T(names[1], names[2]) or tostring(kind or T("待机", "Idle"))
end

local function refresh_assistant_status(player)
  local panel = player.gui.left[PREFIX .. "panel"]
  local live = panel and panel[PREFIX .. "live_section"]
  local grid = live and live[PREFIX .. "assistant_status"]
  if not (grid and grid.valid) then return end
  grid.clear()
  for _, who in ipairs(companion.names()) do
    local c = companion.get(who)
    local active = tasks.active_summary(who)
    local current_health, max_health = 0, 1
    if c then
      pcall(function() current_health = c.health or 0 end)
      pcall(function() max_health = c.max_health or 250 end)
    end
    local health = c and math.floor(100 * current_health / math.max(max_health, 1)) or 0
    local items = c and c.get_main_inventory().get_item_count() or 0
    local work = active and task_name(active.type) or T("待机", "Idle")
    if active and active.resume_type then
      work = work .. T("（之后恢复" .. task_name(active.resume_type) .. "）",
        " (then resume " .. task_name(active.resume_type) .. ")")
    end
    if active and (active.queue_length or 0) > 0 then
      work = work .. string.format(T("；排队%d", "; queued %d"), active.queue_length)
    end
    grid.add({ type = "label", caption = who })
    grid.add({ type = "label", caption = string.format(T("%s｜生命%d%%｜背包%d", "%s | HP %d%% | inventory %d"), work, health, items) })
    local last = tasks.last_result(who)
    if last and last.status == "failed" and game.tick - (last.tick or 0) < 18000 then
      local detail = tostring(last.detail)
      if #detail > 100 then detail = string.sub(detail, 1, 97) .. "..." end
      grid.add({ type = "label", caption = T("最近失败", "Last failure") })
      grid.add({ type = "label", caption = task_name(last.type) .. "：" .. detail })
    end
  end
end

local function close_priorities(player)
  local frame = player.gui.screen[PREFIX .. "priorities_frame"]
  if frame and frame.valid then frame.destroy() end
end

local function open_priorities(player)
  close_priorities(player)
  storage.work_priorities = storage.work_priorities or {}
  storage.local_gui[player.index] = storage.local_gui[player.index] or {}
  local names = companion.names()
  storage.local_gui[player.index].priority_names = names
  local frame = player.gui.screen.add({
    type = "frame", name = PREFIX .. "priorities_frame",
    caption = T("助手工作优先级", "Companion Work Priorities"), direction = "vertical",
  })
  frame.auto_center = true
  frame.add({ type = "label", caption = T("1 最高，4 最低；关闭表示不主动执行。战斗自卫始终优先。", "1 is highest and 4 lowest; Off disables autonomous work. Self-defense always takes priority.") })
  local grid = frame.add({ type = "table", column_count = #WORK_TYPES + 2 })
  grid.add({ type = "label", caption = T("助手", "Companion") })
  for _, work in ipairs(WORK_TYPES) do grid.add({ type = "label", caption = T(work.zh, work.en) }) end
  grid.add({ type = "label", caption = T("搜索半径", "Search radius") })
  local items = { T("关闭", "Off"), "1", "2", "3", "4" }
  for index, who in ipairs(names) do
    grid.add({ type = "label", caption = who })
    local saved = storage.work_priorities[who] or {}
    for _, work in ipairs(WORK_TYPES) do
      local value = saved[work.key]
      if value == nil then value = work.default end
      grid.add({
        type = "drop-down", name = PREFIX .. "priority_" .. index .. "_" .. work.key,
        items = items, selected_index = value == 0 and 1 or value + 1,
      })
    end
    local settings = storage.work_settings and storage.work_settings[who] or {}
    grid.add({ type = "textfield", name = PREFIX .. "work_radius_" .. index,
      text = tostring(settings.radius or 256), numeric = true, allow_decimal = false, allow_negative = false })
  end
  frame.add({ type = "button", name = PREFIX .. "priorities_close", caption = T("完成", "Done") })
end

local function start_custom_patrol(player)
  local state = storage.local_gui[player.index]
  local pending = state and state.pending_patrol
  if not pending or #pending.points < 2 then
    status(player, T("请至少设置两个巡逻点", "Set at least two patrol points"))
    return false
  end
  local assigned = 0
  for _, name in ipairs(pending.companions or {}) do
    if companion.get(name) then
      local points = {}
      for i, point in ipairs(pending.points) do points[i] = { x = point.x, y = point.y } end
      local rec = companion.record(name)
      if rec then rec.saved_patrol_route = points end
      order(player, { type = "patrol", points = points }, name)
      assigned = assigned + 1
    end
  end
  state.pending_patrol = nil
  player.clear_cursor()
  status(player, string.format(T("已命令 %d 个助手循环巡逻 %d 个路线点", "Ordered %d companion(s) to loop through %d patrol points"),
    assigned, #pending.points))
  return true
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
  local frame = player.gui.center.add({ type = "frame", name = PREFIX .. "supply_picker", caption = T("选择生产原材料（一组）", "Choose production input (one stack)"), direction = "vertical" })
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
      caption = { "", prototypes.item[name].localised_name, T("（可用 ", " (available: "), totals[name], T("）", ")") },
    })
  end
  frame.add({ type = "button", name = PREFIX .. "supply_close", caption = T("取消", "Cancel") })
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
    status(player, string.format(T("已命令 %d 个助手采集 %s，完成后送往所选箱子", "Ordered %d companion(s) to mine %s and deliver it to the selected chest"), assigned, pending.resource))
  else
    status(player, string.format(T("已命令 %d 个助手采集 %s，产物保留在各自背包", "Ordered %d companion(s) to mine %s and keep it in their inventories"), assigned, pending.resource))
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
  status(player, string.format(T(
    "已命令 %d 个助手循环工作：每采集 %d 次 %s，向目标投入最多 %d 个",
    "Ordered %d companion(s) to loop: mine %d times for %s, then feed up to %d items"),
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
  if not player or not element or not element.valid then return end
  local priority_index, priority_key = string.match(element.name, "^" .. PREFIX .. "priority_(%d+)_(%a+)$")
  if priority_index then
    local state = storage.local_gui[player.index]
    local who = state and state.priority_names and state.priority_names[tonumber(priority_index)]
    if who then
      storage.work_priorities = storage.work_priorities or {}
      storage.work_priorities[who] = storage.work_priorities[who] or {}
      storage.work_priorities[who][priority_key] = element.selected_index - 1
      status(player, who .. T(" 的工作优先级已更新", " work priorities updated"))
    end
    return
  end
  if element.name ~= PREFIX .. "target" then return end
  storage.local_gui[player.index] = storage.local_gui[player.index] or {}
  local selected = element.get_item(element.selected_index)
  storage.local_gui[player.index].command_target = element.selected_index > 1 and selected or nil
  status(player, T("当前指令对象：", "Current command target: ") .. selected)
end

function M.on_gui_text_changed(event)
  local element = event.element
  if not (element and element.valid) then return end
  local value = math.floor(tonumber(element.text) or 10)
  local radius_index = string.match(element.name, "^" .. PREFIX .. "work_radius_(%d+)$")
  if radius_index then
    local state = storage.local_gui[event.player_index]
    local who = state and state.priority_names and state.priority_names[tonumber(radius_index)]
    if who then
      storage.work_settings = storage.work_settings or {}
      storage.work_settings[who] = storage.work_settings[who] or {}
      storage.work_settings[who].radius = math.max(32, math.min(value, 512))
    end
  elseif element.name == PREFIX .. "fuel_count" then
    storage.autonomy_fuel_target = math.max(1, math.min(value, 1000))
  elseif element.name == PREFIX .. "turret_ammo_count" then
    storage.autonomy_turret_ammo_target = math.max(1, math.min(value, 1000))
  end
end

function M.on_gui_click(event)
  local player = game.get_player(event.player_index)
  local element = event.element
  if not player or not element or not element.valid then return end
  local name = element.name
  local section = string.match(name, "^" .. PREFIX .. "section_(%a+)$")
  if section then
    show_main_section(player, section)
    if section == "live" then pcall(refresh_assistant_status, player) end
    return
  end
  if name == PREFIX .. "language" then
    storage.local_language = english() and "zh" or "en"
    for _, who in ipairs(companion.names()) do
      local rec = companion.record(who)
      if rec then rec.starter_book_version = nil end
    end
    for _, online in pairs(game.connected_players) do
      local old_panel = online.gui.left[PREFIX .. "panel"]
      local was_visible = old_panel and old_panel.visible
      if old_panel and old_panel.valid then old_panel.destroy() end
      local old_toggle = online.gui.top[PREFIX .. "toggle"]
      if old_toggle and old_toggle.valid then old_toggle.destroy() end
      make_gui(online)
      refresh_target_selector(online)
      online.gui.left[PREFIX .. "panel"].visible = was_visible ~= false
    end
    status(player, T("界面和内置蓝图已切换为中文", "Interface and built-in blueprints switched to English"))
    return
  end
  if name == PREFIX .. "priorities" then
    open_priorities(player)
    return
  end
  if name == PREFIX .. "priorities_close" then
    close_priorities(player)
    status(player, T("工作优先级已保存", "Work priorities saved"))
    return
  end
  if name == PREFIX .. "toggle" then
    local panel = player.gui.left[PREFIX .. "panel"]
    panel.visible = not panel.visible
    if panel.visible then pcall(refresh_assistant_status, player) end
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
      status(player, T("蓝图已拿在手上；移动鼠标查看虚影，旋转后点击放置", "Blueprint is on the cursor; move to preview, rotate if needed, then place it"))
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
          status(player, T("请框选接收 ", "Select a machine or chest that accepts ") .. pending.product .. T(" 的生产设备或容器；以后会自动复用直到装满", "; it will be reused until full"))
        end
      elseif state.work_mode == "full" then
        pending.harvest_count = configured_count(player, "harvest_count", 50, 200)
        pending.supply_count = configured_count(player, "supply_count", 50, 1000)
        state.pending_full = pending
        player.clear_cursor()
        player.cursor_stack.set_stack({ name = "agentic-local-production-target-tool", count = 1 })
        status(player, T("已选择 ", "Selected ") .. chosen.resource .. T("；请框选使用该原料的生产设备", "; select a machine that uses this resource"))
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
        status(player, T("请框选一个用于存放矿物的己方箱子；以后会自动复用直到装满", "Select a friendly chest for mined resources; it will be reused until full"))
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
      status(player, T("已选择 ", "Selected ") .. item .. T("；请框选熔炉、生产设备或接收容器", "; select a furnace, production machine or receiving chest"))
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
      status(player, T("请框选要自动取出成品的熔炉或生产设备", "Select a furnace or production machine whose outputs should be collected"))
      return
    elseif name == PREFIX .. "spawn" then
      local added = add_companion(player)
      refresh_target_selector(player)
      status(player, added .. T(" 已生成；当前共有 ", " spawned; there are now ") .. #companion.names() .. T(" 个 AI", " AI companion(s)"))
    elseif name == PREFIX .. "remove" then
      local removed = remove_companion(player)
      refresh_target_selector(player)
      status(player, removed .. T(" 已移除；它的物品已掉落在原地", " removed; its items were dropped at its position"))
    elseif name == PREFIX .. "equip" then
      ensure_companion(player)
      local equipped = 0
      for _, who in ipairs(command_names(player)) do
        companion.set_context(who)
        local good = pcall(equip_carried_weapon, companion.get(who))
        if good then equipped = equipped + 1 end
      end
      companion.set_context(nil)
      status(player, T("已为 ", "Equipped weapons and ammunition for ") .. equipped .. T(" 个所选助手装备武器弹药", " selected companion(s)"))
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
      status(player, T("正在补齐附近设备；可从助手背包或附近己方箱子取燃料", "Refueling nearby machines from companion inventories or friendly chests"))
    elseif name == PREFIX .. "repair" then
      order_all(player, function(c)
        return {
          type = "keep_repaired",
          center = { x = c.position.x, y = c.position.y },
          radius = 256,
          max_empty_scans = 1,
        }
      end)
      status(player, command_label(player) .. T(" 正在寻找并维修受损设备；全部修完后恢复待机", " are finding and repairing damaged machines, then returning to idle when all repairs are complete"))
    elseif name == PREFIX .. "follow" then
      order_all(player, function() return { type = "follow_player", player = player.name, distance = 3 } end)
      status(player, command_label(player) .. T(" 正在跟随你", " are following you"))
    elseif name == PREFIX .. "hold" then
      order_all(player, function(c)
        return {
          type = "defend_area",
          center = { x = c.position.x, y = c.position.y },
          radius = 24,
          turret_ammo_target = storage.autonomy_turret_ammo_target or 10,
        }
      end)
      status(player, command_label(player) .. T(" 正在原地镇守", " are holding position"))
    elseif name == PREFIX .. "patrol" then
      order_all(player, function() return { type = "patrol", radius = 12 } end)
      status(player, command_label(player) .. T(" 正在周边巡逻", " are patrolling nearby"))
    elseif name == PREFIX .. "patrol_custom" then
      ensure_companion(player)
      local state = storage.local_gui[player.index]
      state.pending_patrol = { points = {}, companions = command_names(player) }
      player.clear_cursor()
      player.cursor_stack.set_stack({ name = "agentic-local-patrol-route-tool", count = 1 })
      status(player, T("请按顺序框选巡逻点；设置至少两个点后点击“完成巡逻路线”，或在最后一点右键框选", "Select patrol points in order; after at least two points click Finish Patrol Route, or alt-select the final point"))
    elseif name == PREFIX .. "patrol_finish" then
      start_custom_patrol(player)
    elseif name == PREFIX .. "patrol_saved" then
      local assigned = 0
      for _, who in ipairs(command_names(player)) do
        local rec = companion.record(who)
        if rec and rec.saved_patrol_route and #rec.saved_patrol_route >= 2 then
          local points = {}
          for i, point in ipairs(rec.saved_patrol_route) do points[i] = { x = point.x, y = point.y } end
          order(player, { type = "patrol", points = points }, who)
          assigned = assigned + 1
        end
      end
      status(player, assigned > 0
        and string.format(T("已让 %d 个助手使用保存的巡逻路线", "Started saved routes for %d companion(s)"), assigned)
        or T("所选助手还没有保存的巡逻路线", "The selected companion(s) have no saved patrol route"))
    elseif name == PREFIX .. "attack" then
      local command_center = { x = player.position.x, y = player.position.y }
      order_all(player, function()
        return { type = "fight", target = command_center, radius = 256, hunt = true }
      end)
      status(player, command_label(player) .. T(" 正在主动搜索并清理周围敌人", " are actively hunting nearby enemies"))
    elseif name == PREFIX .. "stop" then
      local selected = command_names(player)
      for _, who in ipairs(selected) do tasks.cancel({ all = true, companion = who }) end
      status(player, T("已停止 ", "Stopped orders for ") .. command_label(player))
    elseif name == PREFIX .. "build" then
      ensure_companion(player)
      player.clear_cursor()
      player.cursor_stack.set_stack({ name = "agentic-local-build-tool", count = 1 })
      status(player, T("请框选蓝图幽灵；材料从助手背包消耗", "Select blueprint ghosts; materials are consumed from companion inventories"))
    elseif name == PREFIX .. "demolish" then
      ensure_companion(player)
      player.clear_cursor()
      player.cursor_stack.set_stack({ name = "agentic-local-demolish-tool", count = 1 })
      status(player, T("请框选己方建筑、树木、岩石或残骸", "Select friendly structures, trees, rocks or wreckage"))
    elseif name == PREFIX .. "mine_supply" then
      ensure_companion(player)
      open_work_mode(player)
    elseif name == PREFIX .. "blueprints" then
      ensure_companion(player)
      open_blueprint_picker(player)
    end
  end)
  companion.set_context(nil)
  if not ok then status(player, T("命令失败：", "Command failed: ") .. tostring(err)) end
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
    status(player, string.format("已把 %d 个目标分配给 %d 个助手；它们会自行寻找箱中材料，逐个走近并%s", accepted, workers, verb))
end

function M.on_selected_area(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  if event.item == "agentic-local-patrol-route-tool" then
    local state = storage.local_gui[player.index]
    local pending = state and state.pending_patrol
    if not pending then
      status(player, T("没有正在设置的巡逻路线", "No patrol route is being configured"))
      player.clear_cursor()
      return
    end
    local area = event.area
    local point = {
      x = (area.left_top.x + area.right_bottom.x) / 2,
      y = (area.left_top.y + area.right_bottom.y) / 2,
    }
    -- Store a standable coordinate beside buildings rather than their centre.
    -- patrol.start performs the same migration for routes saved by old versions.
    point = player.surface.find_non_colliding_position("character", point, 16, 0.25)
      or player.surface.find_non_colliding_position("character", point, 32, 0.5)
      or point
    pending.points[#pending.points + 1] = point
    if event.name == defines.events.on_player_alt_selected_area and #pending.points >= 2 then
      start_custom_patrol(player)
    else
      status(player, string.format(T("已添加第 %d 个巡逻点；继续框选或点击完成", "Added patrol point %d; continue selecting or click Finish"), #pending.points))
    end
  elseif event.item == "agentic-local-build-tool" then
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
  if game.tick % 60 == 0 then
    -- A diagnostic widget must never be able to stop the simulation. Keep the
    -- per-player refresh isolated in case another API or third-party prototype
    -- exposes unusual data.
    for _, player in pairs(game.connected_players) do pcall(refresh_assistant_status, player) end
  end
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
