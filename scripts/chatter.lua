-- Short, rate-limited companion speech. Flying text is cosmetic only and all
-- tactical decisions remain in the task system.
local companion = require("scripts.companion")

local M = {}

local ZH = {
  order = { "收到！", "明白，我这就去。", "交给我吧。", "好，马上处理。", "知道了，开始干活。" },
  hurt = { "我中招了！", "有敌人，注意！", "需要一点支援！", "靠，来真的！", "该死，盯上我了！" },
  spotted = { "发现虫子！", "前方有敌人！", "准备接敌！", "妈的，虫子来了！", "看到虫巢了，小心！" },
  assist = { "收到，正在支援！", "我来帮你！", "一起上，别落单！", "掩护你，继续打！" },
  rally = { "基地遇袭，集合！", "全员支援基地！", "别让虫子冲进来！", "集合，干掉它们！" },
}
local EN = {
  order = { "Got it!", "Understood, moving now.", "Leave it to me.", "On it.", "All right, getting to work." },
  hurt = { "I'm hit!", "Contact, watch out!", "Could use some help!", "Damn, that hurt!", "Hell, they're on me!" },
  spotted = { "Bugs spotted!", "Enemies ahead!", "Prepare to engage!", "Damn, bugs incoming!", "Nest ahead, stay sharp!" },
  assist = { "Copy, moving to assist!", "I'm coming to help!", "Stay together!", "I've got your back!" },
  rally = { "Base under attack, rally!", "All hands, defend the base!", "Don't let them through!", "Rally up, take them down!" },
}

local function lines(kind)
  local group = storage.local_language == "en" and EN or ZH
  return group[kind] or group.order
end

local function speak(name, kind, cooldown)
  local rec = companion.record(name)
  local c = companion.get(name)
  if not (rec and c) then return false end
  rec.chatter_ticks = rec.chatter_ticks or {}
  if (rec.chatter_ticks[kind] or 0) > game.tick then return false end
  rec.chatter_ticks[kind] = game.tick + cooldown
  local pool = lines(kind)
  local message = pool[math.random(1, #pool)]
  local color = kind == "hurt" and { r = 1, g = 0.35, b = 0.25 }
    or (kind == "rally" and { r = 1, g = 0.75, b = 0.15 } or { r = 0.4, g = 1, b = 0.55 })
  -- Factorio 2.0 has no runtime entity prototype named "flying-text".
  -- Display the speech locally for every connected player on this surface.
  -- Keep the visual effect fully guarded: chatter must never stop simulation.
  for _, player in pairs(game.connected_players) do
    if player.surface == c.surface then
      pcall(function()
        player.create_local_flying_text({
          text = message,
          position = { x = c.position.x, y = c.position.y - 2.2 },
          color = color,
          time_to_live = 180,
          speed = 0.02,
        })
      end)
    end
  end
  return true
end

function M.order(names)
  for _, name in ipairs(names or {}) do speak(name, "order", 60) end
end

function M.hurt(name) speak(name, "hurt", 5 * 60) end
function M.spotted(name) speak(name, "spotted", 12 * 60) end
function M.assist(name) speak(name, "assist", 8 * 60) end
function M.rally(name) speak(name, "rally", 10 * 60) end

return M
