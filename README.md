# 异星工厂 AI 玩家助手 / Factorio AI Player Assistant

> 当前版本 / Current version: 0.19.9 — 分类收纳会跳过已满的旧指定箱，自动改用其他可接收同种物品的箱子。

一个完全在 Factorio 2.0 游戏内运行的多助手模组，不需要外部 AI、API、Codex 或 Token。助手像真实角色一样移动、采矿、搬运、建造和战斗，所有物品都来自实际背包、箱子或采集行为。

A multi-companion mod that runs entirely inside Factorio 2.0. It requires no external AI, API, Codex, or tokens. Companions physically move, mine, transport, build, and fight, and every item must come from a real inventory, chest, or mining action.

> **原作者与原项目：Matteo Mekhail — [Agentic-Factorio](https://github.com/matteomekhail/Agentic-Factorio)**
>
> **Original author and project: Matteo Mekhail — [Agentic-Factorio](https://github.com/matteomekhail/Agentic-Factorio)**

本优化版基于 Matteo Mekhail 创建的 Agentic-Factorio 项目中的模组代码继续开发。感谢原作者公开项目和最初设计；本仓库中的本地指令系统及后续功能是在该基础上的重构与扩展，并不声称原始项目为本优化版作者原创。

This enhanced edition continues development from the mod code in Agentic-Factorio, created by Matteo Mekhail. Credit belongs to the original author for publishing the project and its initial design. The local command system and later features in this repository are refactors and extensions of that work, and the original project is not claimed as the work of this edition's maintainer.

## 主要特点 / Main Features

- 成功下达指令后，收到命令的助手会在自己头顶用自然语气回应；发现敌人或受伤时也会说出带冷却的战斗对白，其中偶尔包含轻微脏话。
- After a successful order, each addressed companion answers naturally above its own head. Enemy sightings and injuries also trigger rate-limited combat chatter, with occasional mild profanity.

- 玩家或己方建筑遭敌人攻击时，同一地表的所有助手会暂时放下当前工作、集结到遇袭点共同防守；战斗结束后恢复各自原来的任务。
- When the player or a friendly structure is attacked, every companion on that surface suspends its current work and rallies to defend the attacked area, then resumes the previous task after combat.

- 最多生成十名助手，可向全部助手或单个助手下达命令；管理页可为选中的单个助手改名，任务、设置、路线和地图标记会随名称完整迁移。
- Spawn up to ten companions and command all of them or an individual companion. A selected helper can be safely renamed from Manage, with tasks, settings, routes and map markers migrated to the new identity.

- 助手死亡后等待 10 秒在玩家附近复活，再自动返回死亡地点取回自己的遗留物品；死亡物品不会复制。
- Companions respawn near the player after 10 seconds, then automatically return to recover their own death items without duplication.

- 待机时会把背包或附近己方箱子中的可熔炼矿物送入兼容熔炉，所有取料和投料都由助手亲自完成。
- While idle, companions deliver smeltable materials from their inventories or nearby friendly chests to compatible furnaces, physically performing every pickup and delivery.

- 补燃料优先保障发电设备并尽量填满其燃料库存，之后再按设定数量补充普通设备。
- Refueling prioritizes power equipment and fills its fuel inventory whenever possible before servicing ordinary machines to the configured amount.

- 炮塔目标弹药数量可在面板自定义；补弹前会优先从背包或己方箱子补满助手当前武器的一组弹药，只有主背包中多余的兼容弹药才能交给炮塔，装备槽中的自用弹药不会被取走。
- Turret ammunition targets are configurable. Before servicing a turret, a companion fills one stack for its selected weapon from carried or stored supplies; only compatible surplus in the main inventory may be donated, never equipped personal ammunition.
- 每个助手都可像《环世界》一样单独设置维修、补燃料、炮塔补弹、生产投料、巡逻和采矿的工作优先级（1–4 或关闭）；同级工作会轮换，战斗自卫始终优先。
- Each companion has RimWorld-style individual priorities (1–4 or Off) for repair, refueling, turret supply, production input, patrol and mining; equal-priority jobs rotate, while self-defense always comes first.
- 主面板实时显示每个助手的当前工作、生命、背包数量、排队任务、战斗后恢复任务及最近失败原因。
- 主面板使用“常用、工作、管理、状态”四个分页，平时只显示当前需要的一组按钮，减少滚动和误操作。
- 管理页提供维护员、矿工、守卫、生产助手和全能助手职业模板；状态页可直接定位或停止当前所选助手。
- 工作页可为单个或全部助手设置固定工作中心；个人搜索半径将围绕该中心生效，清除后恢复随助手当前位置移动。
- The main panel shows each companion's live work, health, inventory count, queued work, post-combat resume task and recent failure reason.
- 每个助手可设置32–512格的自主搜索半径，维修、燃料、炮塔、生产和待机采矿只搜索其当前位置周围的指定范围。
- Each companion has a 32–512 tile autonomous search radius applied to repair, fuel, turrets, production and idle mining around its current position.

- 可在地图上依次设置多个自定义巡逻点，向全部或单个助手下达循环巡逻路线；助手会沿途战斗并在战后恢复路线。
- Define multiple ordered patrol points on the map and assign the looping route to all companions or an individual; companions fight along the way and resume the route afterward.

- 自定义路线会按助手分别保存并可一键重新使用；巡逻中缺枪或弹药时，助手会从己方箱子取得兼容装备后继续路线。
- 自定义及保存的巡逻路线严格按设置顺序循环；寻路重试或战斗结束后仍会先到达当前路线点，不会跳点。
- 巡逻点与炮塔或其他建筑重叠时会自动调整到建筑旁最近的可站立位置，旧路线同样会自动校正。
- 巡逻使用严格寻路；路径失败或超时时只会重新规划，不会启用穿过墙体的直线移动。
- Custom routes are saved per companion and can be restarted with one click; patrolling companions retrieve compatible guns or ammunition from friendly chests before resuming their route.

- 遭遇战只会临时挂起维修、补给、施工或巡逻；战斗结束后助手会从当前位置重新寻路并恢复原任务进度。
- Encounters temporarily suspend repairs, supply, construction, or patrol work; after combat, companions re-path from their current position and resume the original task progress.

- 维修包按当前设备实际损伤计算取用；手动维修清空目标后结束，助手恢复正常待机并继续自动关注新损坏。
- Repair packs are collected according to the current machine's actual damage; manual repair ends when the area is clear, returning the companion to idle monitoring for new damage.

- 跟随、原地镇守、巡逻、主动清理敌人和停止命令。
- Follow, hold position, patrol, clear nearby enemies, and stop commands.

- 正在跟随玩家的助手会在玩家进入载具且乘客位空闲时自动上车，不会抢占驾驶位；玩家下车或更换载具时助手同步下车并继续步行跟随。玩家驾驶时，乘客助手优先选择载具中有弹药的车载武器攻击射程内敌人，车载武器不可用时才使用自身武器；所有射击消耗真实弹药。没有空位的其他助手继续在地面跟随。
- A companion following the player automatically boards an available passenger seat without taking the driver's seat, then exits and resumes following when the player leaves or changes vehicles. While the player drives, the passenger selects a loaded vehicle weapon and attacks enemies in range, falling back to its personal weapon when vehicle armament is unavailable. Every shot consumes real ammunition. Additional helpers stay on foot when no seat is free.

- 助手拥有独立背包，拿取距离、移动速度、采矿时间和拆除时间遵循原版角色规则。
- Each companion has an independent inventory. Reach distance, movement speed, mining time, and deconstruction time follow vanilla character rules.

- 框选建筑幽灵后由助手亲自建造；框选建筑、树木、岩石或残骸后由助手亲自拆除。
- Companions physically construct selected ghosts and physically deconstruct selected buildings, trees, rocks, or wreckage.

- 蓝图使用原版光标放置体验，显示完整建筑虚影、可放置状态及材料需求清单。
- 每名助手施工前会汇总自己负责的全部建筑，拜访箱子时一次领取其中所有需要且背包装得下的材料，减少按单个建筑往返。
- 蓝图预览使用的临时光标副本会在放置后直接销毁，不会凭空进入玩家背包；最近一次蓝图的材料清单常驻小地图下方，也可从工作页随时重新打开。
- Blueprints use the native cursor placement experience with full ghost previews, placement validity, and a material requirement list.

- 蓝图放置后，助手会在施工区域 256 格内主动寻找存有材料的己方箱子，亲自取料、返回并逐个建造虚影。
- After a blueprint is placed, companions search friendly chests within 256 tiles of the construction area, physically retrieve materials, return, and build each ghost.

- 内置四套蓝图书及全部子蓝图均已汉化；指令面板可在中文和英文之间整体切换，切换后自动换发对应语言的蓝图。
- All four built-in blueprint books and every nested blueprint are localized. The command panel can switch globally between Chinese and English and automatically reissues blueprints in the selected language.

- 采集、生产投料和成品收纳可以全流程循环，也可以分别单独使用。
- Mining, production feeding, and finished-product storage can run as one complete loop or as separate tasks.

- 不同成品可映射到不同箱子，助手会记住“成品 → 箱子”的分类规则。
- Different products can be mapped to different chests, and companions remember each product-to-chest sorting rule.

- 常用页提供原版物品选择列表和数量输入框；助手会先从自己背包取物，不足时走到己方箱子领取，再追上玩家并亲手交付。选择“全部助手”时只派出一名，避免重复送来十份。
- The Orders page provides Factorio's native item picker and an amount field. A helper uses carried stock first, visits friendly chests for the remainder, catches the player and physically hands it over. Selecting All companions dispatches only one helper to prevent duplicate deliveries.

- 打开熔炉、组装机、研究所或火箭发射井时，原版设备窗口右侧会显示该设备专属的“助手自动投料清单”；可登记多种物品及各自目标数量。规则随存档保存，待机助手按自己的生产投料优先级持续补充真实物资。
- Opening a furnace, assembling machine, lab or rocket silo shows that machine's own Companion Input List beside the native GUI. Multiple item targets can be saved per machine; idle helpers service them through their production priority using only real supplies.

- 投料清单严格校验设备当前配方：组装机和发射井只接受当前配方原料，熔炉只接受其冶炼类别原料，研究所只接受支持的科技包。燃料和模块不会混入生产投料；更换配方后不兼容的旧规则会显示为停用。
- “生产投料”只服务打开设备后明确加入清单的机器，不再自动寻找未标注生产线。燃烧设备会连同燃料一起维护；点击设备侧栏的“设置成品收纳箱”后，只在成品库存满时搬往指定箱子。
- 打开己方箱子可在右侧登记该箱接收的成品种类。同一种成品只需在一个或多个箱子中登记，所有已标注生产设备都会自动寻找可用目标箱，不再需要逐台设备指定。
- 生产助手会优先把自己背包中与箱子清单匹配的物品送入对应箱子；设备进入原版“成品已满”停机状态时也会立即取出，不再只依赖物理库存槽是否全满。
- 每条设备原料规则同时设置“目标数量”和“补货阈值百分比”；默认降到目标的 25% 以下才一次补回目标数量，避免少一个物品就往返。
- Input lists are recipe-strict: assemblers and silos accept only current recipe ingredients, furnaces accept only valid smelting inputs, and labs accept supported science packs. Fuel and modules cannot leak into production input; stale rules pause visibly after a recipe change.

- 自动检查燃料目标数量，依次给多个设备补充；优先使用助手背包或己方箱子中的煤炭，没有可用煤炭时才使用其他兼容燃料，全部缺少时会寻找煤矿并实际开采。
- 从箱子取燃料时会汇总个人搜索范围内的兼容设备需求，一次尽量带够整批燃料后连续补充，避免每补一台就返回箱子。
- Automatically checks target fuel levels and services multiple machines; when neither inventories nor chests contain fuel, the companion finds and physically mines coal.

- 主动寻找受损的己方设备并连续维修；优先使用助手背包里的修理包，没有时会走到设备附近的己方箱子取用，绝不凭空生成。
- Actively finds and repairs damaged friendly machines; it first uses repair packs in its own inventory, otherwise walks to a friendly chest near the machine, and never creates packs from nothing.

- 受到攻击时根据血量、武器弹药、敌人数和附近友方力量决定反击或撤退，战斗结束后恢复原任务。
- When attacked, companions decide whether to fight or retreat based on health, weapons, ammunition, enemy count, and nearby allied strength, then resume the previous task.

- 空闲时按照补燃料、采矿、巡逻的优先级自主工作，同一种空闲工作最多两名助手执行。
- While idle, companions autonomously prioritize refueling, mining, then patrol; no more than two companions perform the same idle activity.

## 安装方法 / Installation

1. 下载发布页面中的 `agentic-companion_0.9.7.zip`。
2. 将 ZIP 放入 Factorio 的 `mods` 文件夹，不要解压。
3. 完全退出并重新启动 Factorio，然后启用模组并载入存档。

1. Download `agentic-companion_0.9.7.zip` from the Releases page.
2. Place the ZIP in Factorio's `mods` folder without extracting it.
3. Fully restart Factorio, enable the mod, and load your save.

Windows 默认模组目录：`%APPDATA%\Factorio\mods`

Default Windows mod directory: `%APPDATA%\Factorio\mods`

## 使用方法 / Usage

点击顶部的“助手命令”打开控制面板，选择全部助手或指定助手，然后使用对应按钮下令。成功命令会以玩家说话口吻显示在头顶并写入聊天栏；失败信息只显示在左侧状态栏。

Click “Companion Commands” at the top to open the control panel. Select all companions or one companion, then choose a command. Successful commands appear above the player in a spoken-command style and in chat; failures only appear in the left status panel.

“采集·生产·收纳”提供全流程、采集并投料、只采集、只生产投料和只收纳五种模式。全流程依次执行采集原料、投入设备、等待生产、取出成品和分类入箱。

“Mine · Produce · Store” provides five modes: full workflow, mine and feed, mining only, production feeding only, and output storage only. The full workflow mines raw materials, feeds a machine, waits for production, collects products, and sorts them into mapped chests.

## 公平性与兼容性 / Fairness and Compatibility

模组不会凭空生成建筑、燃料、弹药或生产材料。助手必须从自己的背包、己方箱子或真实采集行为取得物品。支持 Factorio 2.0，已使用 Factorio 2.0.77 验证加载。

The mod never creates buildings, fuel, ammunition, or production materials from nothing. Companions must obtain items from their own inventories, friendly chests, or real mining actions. It supports Factorio 2.0 and has been load-tested with Factorio 2.0.77.

## 存档兼容 / Save Compatibility

旧版本存档可以升级到新版本。建议更新前备份存档，并在首次成功载入新版后另存一个新存档。正在执行的旧任务在内部结构变化时可能重新开始，但地图、助手和背包物品会保留。

Saves from earlier versions can be upgraded. Back up the save before updating and create a new save after the first successful load. Active tasks may restart when internal task structures change, but the map, companions, and inventory items are preserved.

## 更新日志 / Changelog

完整版本记录请查看 [CHANGELOG.md](CHANGELOG.md)。

See [CHANGELOG.md](CHANGELOG.md) for the complete version history.

## 来源与致谢 / Origin and Credits

原作者为 Matteo Mekhail。本项目基于其 Agentic-Factorio 的模组部分进行本地化重构和扩展，目标是提供无需外部模型、无需 Token 的游戏内助手体验。原项目 README 声明使用 MIT License；请同时参阅本仓库的 [NOTICE.md](NOTICE.md)。

The original author is Matteo Mekhail. This project is a localized refactor and extension of the mod portion of Agentic-Factorio, focused on an in-game companion experience that requires no external model or tokens. The original project's README declares the MIT License; also see this repository's [NOTICE.md](NOTICE.md).

原项目 / Original project: https://github.com/matteomekhail/Agentic-Factorio
