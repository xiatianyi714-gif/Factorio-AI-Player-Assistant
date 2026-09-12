-- build_blueprint: build a WHOLE reachable blueprint (starter books, player
-- inventory/books, cursor) at an anchor in one task — the model never has to
-- read the entities or copy positions. Resolution and normalization live in
-- scripts/blueprint.lua; the per-step walking/placing machinery is
-- build_plan's (same task shape, so its tick runs unchanged). Failed steps
-- (missing items, blocked ground) are reported per step like build_plan.
local companion = require("scripts.companion")
local blueprint = require("scripts.blueprint")
local build_plan = require("scripts.actions.build_plan")

local M = {}

-- Machine-generated steps, so far beyond build_plan's hand-written cap.
local MAX_ENTITIES = 1000

function M.start(task)
  companion.require_companion()
  local anchor = task.anchor
  if type(anchor) ~= "table" or type(anchor.x) ~= "number" or type(anchor.y) ~= "number" then
    error("build_blueprint requires anchor = {x, y} — where the print's top-left entity goes")
  end
  if type(task.label) ~= "string" or task.label == "" then
    error("build_blueprint requires label = <blueprint label> (see list_blueprints)")
  end

  local resolved = blueprint.resolve_for_build({
    label = task.label,
    book = task.book,
    player = task.player,
  })

  -- Pull missing building items from same-force chests the helper can
  -- physically reach. Nothing is created: every inserted item is removed
  -- from its source chest.
  local c = companion.require_companion()
  local chest_types = { "container", "logistic-container" }
  for item_name, needed in pairs(resolved.items_needed or {}) do
    local missing = needed - c.get_item_count(item_name)
    if missing > 0 then
      for _, box in ipairs(c.surface.find_entities_filtered({
        position = c.position,
        radius = c.reach_distance,
        force = c.force,
        type = chest_types,
      })) do
        if missing <= 0 then break end
        local inv = box.get_inventory(defines.inventory.chest)
        if inv then
          local available = inv.get_item_count(item_name)
          if available > 0 then
            local moved = c.get_main_inventory().insert({ name = item_name, count = math.min(available, missing) })
            if moved > 0 then
              inv.remove({ name = item_name, count = moved })
              missing = missing - moved
            end
          end
        end
      end
    end
  end
  if #resolved.entities > MAX_ENTITIES then
    error(string.format(
      "'%s' has %d entities — build_blueprint takes at most %d; read it in windows and build with build_plan batches instead",
      resolved.label or task.label, #resolved.entities, MAX_ENTITIES))
  end

  local steps = {}
  for i, e in ipairs(resolved.entities) do
    steps[i] = {
      item = e.item,
      entity = e.name,
      position = { x = anchor.x + e.position.x, y = anchor.y + e.position.y },
      direction = e.direction,
      recipe = e.recipe,
    }
  end
  task.steps = steps
  task.label = resolved.label
  task._skipped = (#resolved.skipped > 0) and table.concat(resolved.skipped, ", ") or nil

  -- Same init contract as build_plan.start (its tick drives the task).
  task.stop_on_error = task.stop_on_error == true
  task._index = 1
  task._placed = 0
  task._results = {}
  task._failures = {}
end

function M.tick(task)
  local res = build_plan.tick(task)
  if res and task._skipped then
    res.detail = (res.detail or "") .. " — skipped unknown entities: " .. task._skipped
  end
  return res
end

return M
