# 更新日志 / Changelog

## 0.9.14 — 补燃料轮巡 / Refueling Rounds

- 修复发电设备燃料未完全装满时反复获得最高优先级、导致助手一直停留在同一设备旁的问题。
- Fixed partially filled power equipment repeatedly receiving top priority and keeping a companion beside the same machine.

- 每台设备成功补充或尝试处理一次后，本轮会标记为已处理；助手继续寻找其他发电设备和普通燃烧设备，完成整轮后等待 10 秒再重新巡检。
- After one successful refill or service attempt, a machine is marked complete for the current round. The companion continues to other power and ordinary burner machines, then waits 10 seconds before starting a new round.

- 发电设备仍然优先且单次尽量填满，但燃料不足时不会长期占用助手。
- Power equipment remains prioritized and is filled as much as possible per visit, but no longer monopolizes a companion when fuel is insufficient.

## 0.9.13 — 自定义炮塔补弹 / Configurable Turret Resupply

- 指令面板新增“炮塔目标弹药数量”，可在 1–1000 之间自定义；原地镇守会按此数量补充兼容弹药，不再固定为 10 发。
- Added a 1–1000 “Target turret ammunition” setting. Hold-position duty now supplies compatible ammunition to this target instead of a fixed 10 rounds.

- 待机助手会主动扫描 256 格内缺弹的己方弹药炮塔，从自身背包或己方箱子取得兼容弹药，亲自走过去补充；最多两名助手同时补弹。
- Idle companions scan for low-ammunition friendly turrets within 256 tiles, obtain compatible ammunition from their inventories or friendly chests, and physically resupply them, with at most two companions assigned at once.

- 不会凭空生成弹药，取箱和填充均遵守助手的正常拿取距离。
- Ammunition is never spawned, and chest pickup and turret insertion both respect normal companion reach.

## 0.9.12 — 复活后取回死亡物品 / Post-Respawn Item Recovery

- 助手复活后会自动返回自己的死亡地点，从附近尸体或地面取回死亡时携带的物品，然后恢复正常待机。
- After respawning, a companion automatically returns to its death location, retrieves the items it carried from the nearby corpse or ground, and resumes normal idle behavior.

- 死亡时会记录物品名称和数量，只回收本次死亡清单中的物品，避免误拿死亡地点附近的其他掉落物；不会复制物品。
- Item names and quantities are recorded at death, so only items in that death manifest are recovered, avoiding unrelated nearby drops and preventing duplication.

- 如果死亡物品已被玩家取走、无法到达或新背包空间不足，助手会保留已取回的部分并结束回收任务。
- If items were already taken, are unreachable, or do not fit in the new inventory, the companion keeps what it recovered and ends the recovery task.

- 补燃料时优先处理锅炉、燃烧发电机和核反应堆等发电设备，并尽量把发电设备的燃料库存填满；普通设备仍使用面板设置的目标数量。
- Refueling now prioritizes power equipment such as boilers, burner generators, and reactors, filling their fuel inventories as far as possible while ordinary machines continue using the configured target amount.

## 0.9.11 — 待机自动熔炼与助手复活 / Autonomous Smelting and Companion Respawn

- 待机助手背包里有可熔炼矿物时，会主动寻找 256 格内能够接收该矿物的己方熔炉，亲自走到旁边投入，每次最多投入 50 个。
- When an idle companion carries smeltable ore, it finds a compatible friendly furnace within 256 tiles, walks to it, and inserts up to 50 items per trip.

- 助手背包没有矿石时，也会主动寻找己方箱子里的可熔炼矿物，走到箱子旁取料后再送往兼容熔炉。
- When its inventory has no ore, the companion also searches friendly chests, physically retrieves smeltable materials, and delivers them to a compatible furnace.

- 自动识别熔炉支持的配方分类与实际可接受物品，避免把无对应熔炼配方的背包物品误当作原料；该任务不会创造任何物品。
- Furnace crafting categories and accepted items are checked to avoid treating unrelated inventory contents as ingredients; this task never creates items.

- 待机顺序调整为战斗、维修、补燃料、矿物投料、巡逻、挖矿，玩家明确下达的命令仍然优先。
- The idle order is now combat, repair, refueling, ore feeding, patrol, and mining; explicit player commands still take priority.

- 助手死亡后会像玩家一样等待 10 秒，然后在当前玩家附近以原名称复活；死亡时的任务会取消，原背包物品仍按死亡机制留在死亡地点，不会在复活时复制。
- After death, a companion waits 10 seconds and respawns near the current player with the same name. Its task is cancelled, and death inventory remains at the death location instead of being duplicated on respawn.

## 0.9.10 — 主动搜索敌人 / Active Enemy Hunting

- “清理敌人”命令改为以玩家下令位置为中心搜索 256 格范围，不再只检查助手脚下 40 格。
- “Clear Enemies” now searches within 256 tiles of the player's command position instead of only 40 tiles around each companion.

- 助手找到敌人后会主动寻路接近并连续寻找下一个目标，同时保留弹药、血量、敌我数量判断和撤退逻辑。
- After finding an enemy, companions actively path toward it and continue to the next target while retaining ammunition, health, force-balance, and retreat decisions.

## 0.9.9 — 待机挖矿优先级调整 / Idle Mining Priority Adjustment

- 将助手待机时的自动挖矿降为最低优先级；现在依次优先处理战斗、主动维修、补齐燃料和巡逻，只有前述工作都未分配时才会挖矿。
- Automatic mining is now the lowest-priority idle activity. Companions prioritize combat, autonomous repairs, refueling, and patrol, and mine only when none of those jobs are assigned.

## 0.9.8 — 蓝图自主取料施工 / Autonomous Blueprint Material Retrieval

- 助手施工原版蓝图虚影时，会统计尚未建造的同类建筑数量，并在施工区域 256 格内寻找存有对应材料的己方箱子。
- While constructing native blueprint ghosts, companions count the remaining buildings of each type and search friendly chests within 256 tiles of the construction area for the required materials.

- 助手会亲自走到箱子旁取走真实材料，再返回蓝图位置逐个施工；不会凭空生成物品，也不再要求箱子必须在当前伸手距离内。
- Companions physically walk to chests, retrieve real materials, return to the blueprint, and construct it piece by piece; no items are created and chests no longer need to be within immediate reach.

- 修复缺少第一件材料时直接跳过蓝图建筑、最终表现为没有建造任何东西的问题；无法到达的箱子会被跳过并继续寻找其他库存。
- Fixed blueprint entities being immediately skipped when the first required item was missing, which could result in nothing being built; unreachable chests are skipped while other stocked chests are searched.

## 0.9.7 — 蓝图汉化与语言切换 / Blueprint Localization and Language Switching

- 汉化四套内置蓝图书、嵌套分组、全部子蓝图名称及已有说明，保留作者署名、坐标和功率参数。
- Localized all four built-in blueprint books, nested groups, blueprint names, and existing descriptions while preserving author credits, coordinates, and power ratings.

- 指令面板顶部新增语言按钮，可在中文和英文之间整体切换，默认中文并保存到存档。
- Added a language button at the top of the command panel to switch globally between Chinese and English; Chinese is the default and the choice is saved.

- 切换语言后会自动重建助手界面，并为助手换发对应语言的蓝图书；无需重新生成助手。
- Switching language rebuilds the companion interface and reissues blueprint books in that language without respawning companions.

## 0.9.6 — 主动维修 / Autonomous Repairs

- 新增“主动维修”按钮，可向全部助手或单个助手下达持续维修命令。
- Added an “Autonomous Repairs” button for persistent maintenance by all companions or one selected companion.

- 助手会寻找受损的己方设备并亲自走到设备旁维修，完成一台后继续寻找下一台。
- Companions find damaged friendly machines, walk into reach, repair them, and continue to the next machine.

- 优先消耗助手背包中的真实修理包；没有时会到受损设备附近的己方箱子取用，不会凭空生成。
- Real repair packs are consumed from the companion's inventory; when empty, it retrieves packs from a friendly chest near the damaged machine and never creates them from nothing.

- 空闲助手会优先处理受损设备，同一自主维修工作最多分配两名助手。
- Idle companions prioritize damaged machines, with at most two helpers assigned to autonomous repair work.

## 0.9.5 — 安全采矿与自主燃料获取 / Safe Mining and Autonomous Fuel Acquisition

- 采矿前验证目标，跳过被己方建筑覆盖的矿点，避免误拆玩家建筑。
- Mining targets are validated first, and ore covered by friendly buildings is skipped to prevent accidental deconstruction.

- 补燃料任务会连续寻找并处理多个缺燃料设备，而不是完成一个后停下。
- Refueling now continues across multiple low-fuel machines instead of stopping after one.

- 助手背包和附近箱子都没有燃料时，会寻找已探索区域内的煤矿，按原版时间采煤后返回补充。
- If neither the companion nor nearby chests contain fuel, it searches explored terrain for coal, mines it with vanilla timing, and returns to refuel the machine.

## 0.9.4 — 空设备配方推断 / Empty-Machine Recipe Inference

- 空熔炉可根据所选原料推断成品，例如铁矿推断为铁板。
- Empty furnaces infer their product from the selected input, such as iron ore to iron plates.

- 开始全流程前，助手会取出设备中已有的输入和成品并暂存在独立背包中。
- Before starting a full workflow, the companion collects existing inputs and outputs into its own inventory.

## 0.9.3 — 原版蓝图放置 / Native Blueprint Placement

- 蓝图改用原版光标虚影放置，并显示材料需求、现有数量和缺少数量。
- Blueprints now use native cursor ghost placement and show required, available, and missing materials.

## 0.9.2 — 真实命令气泡 / Natural Command Speech

- 成功命令在玩家头顶以真实下令口吻显示；失败只显示在状态栏。
- Successful commands appear above the player as natural spoken orders; failures remain in the status panel only.

## 0.9.1 — 采集生产收纳全流程 / Complete Mine-Produce-Store Workflow

- 将采集、投料、等待生产、取出成品和分类收纳组合为可循环的完整流程，同时保留各自单独模式。
- Added a repeatable end-to-end workflow covering mining, feeding, production waiting, output collection, and classified storage, while retaining standalone modes.

## 0.9.0 — 成品分类收纳 / Classified Product Storage

- 支持不同成品指定不同箱子，并由多个助手协同搬运。
- Added product-to-chest mappings and coordinated collection by multiple companions.

## 0.8.9 — 智能燃料目标 / Intelligent Fuel Targets

- 自动把设备燃料补到设定目标数量，并保存该设置。
- Machines are automatically topped up to a configured target amount, and the setting is preserved.

## 0.8.8 — 空闲任务分工 / Idle Task Coordination

- 空闲助手优先补燃料，其次采矿和巡逻；同一空闲工作最多两名助手。
- Idle companions prioritize refueling, then mining and patrol, with at most two companions on the same idle activity.

## 0.8.7 — 采矿与投料循环 / Mine-and-Feed Loop

- 合并采矿与生产投料，支持采集批量和每次投入数量，并记忆目标容器。
- Combined mining and production feeding with configurable batch sizes and remembered targets.

## 0.8.6 — 战术判断与任务恢复 / Tactical Decisions and Task Resumption

- 战斗根据血量、装备、敌我数量动态判断；战斗结束恢复原任务。
- Combat decisions dynamically consider health, equipment, and local force balance; previous work resumes afterward.

## 0.8.5 — 自动自卫与徒手战斗 / Automatic Self-Defense and Melee

- 受到攻击时自动反击；无枪或无弹药时可以徒手战斗，低血量时撤退。
- Companions automatically defend themselves, use melee without a usable gun, and retreat at low health.

## 0.8.4 — 主动寻找燃料设备 / Active Fuel-Machine Search

- 扩大设备搜索范围，并围绕目标设备寻找燃料箱。
- Expanded machine discovery and searches for fuel chests around the target machine.

## 0.8.3 — 燃料兼容修复 / Fuel Compatibility Fix

- 修复运行时燃料兼容性检测，使助手能正确识别煤等燃料。
- Fixed runtime fuel compatibility checks so coal and other valid fuels are recognized correctly.

## 0.8.2 及更早版本 / Version 0.8.2 and Earlier

- 增加多助手、单独下令、建造拆除、原版采矿时间、独立背包、战斗巡逻、补给、蓝图施工和纯本地控制基础功能。
- Introduced multiple companions, individual commands, physical construction and deconstruction, vanilla mining timing, separate inventories, combat patrols, supply actions, blueprint construction, and fully local control.
