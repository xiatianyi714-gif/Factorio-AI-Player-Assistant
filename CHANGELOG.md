# 更新日志 / Changelog

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
