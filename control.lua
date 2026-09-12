local state = require("scripts.state")
local rpc = require("scripts.rpc")
local chat = require("scripts.chat")
local companion = require("scripts.companion")
local tasks = require("scripts.tasks")
local perceive = require("scripts.perceive")
local inspect = require("scripts.inspect")
local analyze = require("scripts.analyze")
local research = require("scripts.research")
local walk = require("scripts.actions.walk")
local drive = require("scripts.actions.drive")
local equipment = require("scripts.equipment")
local spatial = require("scripts.spatial")
local blueprint = require("scripts.blueprint")
local screenshot = require("scripts.screenshot")
local local_gui = require("scripts.local_gui")
local idle = require("scripts.idle")
local combat_coordinator = require("scripts.combat_coordinator")
local chatter = require("scripts.chatter")

rpc.register("ping", function()
  return {
    protocol_version = 4,
    mod_version = script.active_mods["agentic-companion"],
    factorio_version = script.active_mods["base"],
    tick = game.tick,
    companion_exists = companion.get() ~= nil,
    companion_movement_speed = companion.movement_speed_multiplier(),
  }
end)
rpc.register("spawn_companion", companion.spawn)
rpc.register("get_chat", chat.get)
rpc.register("say", chat.say)
rpc.register("get_state", perceive.get_state)
rpc.register("check_inventory", perceive.check_inventory)
rpc.register("inspect", inspect.inspect)
rpc.register("analyze_factory", analyze.analyze_factory)
rpc.register("start_research", research.start_research)
rpc.register("equip", equipment.equip)
rpc.register("scan_area", spatial.scan_area)
rpc.register("can_place", spatial.can_place)
rpc.register("find_buildable_area", spatial.find_buildable_area)
rpc.register("describe_prototype", spatial.describe_prototype)
rpc.register("import_blueprint", blueprint.import)
rpc.register("list_blueprints", blueprint.list)
rpc.register("read_blueprint", blueprint.read)
rpc.register("take_screenshot", screenshot.take)
rpc.register("exit_vehicle", drive.exit)
local trains = require("scripts.trains")
rpc.register("list_trains", trains.list_trains)
rpc.register("set_train_schedule", trains.set_train_schedule)
local events = require("scripts.events")
rpc.register("get_events", events.get)
-- starter.lua can't require scripts.events itself (require cycle via
-- companion.lua), so its failure reporting is injected here.
local starter = require("scripts.starter")
starter.notify = events.push
rpc.register("enqueue", tasks.enqueue)
rpc.register("get_task", tasks.get)
rpc.register("cancel", tasks.cancel)
-- get_chunk and echo are registered inside rpc.lua itself.

remote.add_interface("agentic", {
  rpc = function(method, params_json)
    rpc.dispatch(method, params_json)
  end,
})

local function initialize()
  state.init()
  if storage.stop_old_autonomous_tasks then
    tasks.cancel_autonomous()
    storage.stop_old_autonomous_tasks = nil
  end
  companion.apply_movement_speed()
  local_gui.initialize()
end

script.on_init(initialize)
script.on_configuration_changed(initialize)
script.on_event(defines.events.on_runtime_mod_setting_changed, companion.on_runtime_setting_changed)
script.on_event(defines.events.on_player_created, local_gui.on_player_created)
script.on_event(defines.events.on_player_display_resolution_changed, local_gui.on_display_changed)
script.on_event(defines.events.on_player_display_scale_changed, local_gui.on_display_changed)
script.on_event(defines.events.on_gui_click, local_gui.on_gui_click)
script.on_event(defines.events.on_gui_selection_state_changed, local_gui.on_gui_selection_changed)
script.on_event(defines.events.on_gui_text_changed, local_gui.on_gui_text_changed)
script.on_event(defines.events.on_gui_opened, local_gui.on_gui_opened)
script.on_event(defines.events.on_gui_closed, local_gui.on_gui_closed)
script.on_event(defines.events.on_player_selected_area, local_gui.on_selected_area)
script.on_event(defines.events.on_player_alt_selected_area, local_gui.on_selected_area)
script.on_event(defines.events.on_console_chat, chat.on_console_chat)
script.on_nth_tick(120, function()
  companion.update_map_tag()
  companion.ensure_starter_books()
end)
script.on_nth_tick(60, companion.snapshot_inventories)
script.on_nth_tick(300, idle.update)
script.on_event(defines.events.on_tick, function()
  for _, recovery in ipairs(companion.process_respawns()) do
    if recovery.position then
      companion.set_context(recovery.name)
      tasks.enqueue({
        task = {
          type = "recover_death_items",
          target = recovery.position,
          surface_index = recovery.surface_index,
          items = recovery.items,
        },
        replace = true,
        background = true,
        quiet = true,
      })
    end
  end
  companion.set_context(nil)
  combat_coordinator.on_tick()
  tasks.on_tick()
  local_gui.on_tick()
end)
script.on_event(defines.events.on_built_entity, local_gui.on_built_entity,
  { { filter = "type", type = "entity-ghost" } })
script.on_event(defines.events.on_script_path_request_finished, walk.on_path_finished)
script.on_event(defines.events.on_entity_damaged, function(event)
  events.on_entity_damaged(event)
  local entity = event.entity
  if not (entity and entity.valid) then return end
  local attacker = event.cause
  if not (attacker and attacker.valid and attacker.force ~= entity.force) then return end
  if entity.force == game.forces.player then
    local last_rally = storage.last_base_rally_tick
    if not last_rally or game.tick - last_rally >= 5 * 60 then
      storage.last_base_rally_tick = game.tick
      combat_coordinator.rally_all(entity.surface, entity.position)
    end
  end
  for _, name in ipairs(companion.names()) do
    local c = companion.get(name)
    if c == entity then
      chatter.hurt(name)
      local rec = companion.record(name)
      local last = rec and rec.self_defense_tick
      local active = tasks.active_summary(name)
      if (not active or active.type ~= "fight") and (not last or game.tick - last >= 120) then
        if rec then rec.self_defense_tick = game.tick end
        tasks.interrupt_for_combat(name, {
          type = "fight",
          target = { x = entity.position.x, y = entity.position.y },
          radius = 30,
          flee_below = 0.3,
          tactical = true,
        })
        companion.set_context(nil)
      end
      break
    end
  end
end, { { filter = "type", type = "character" } })
script.on_event(defines.events.on_entity_died, function(event)
  events.on_entity_died(event)
  local name = companion.schedule_respawn(event.entity)
  if name then tasks.cancel({ all = true, companion = name }) end
end, { { filter = "type", type = "character" } })
script.on_event(defines.events.on_research_finished, events.on_research_finished)
