# 更新日志 / Changelog

## 0.15.4

### 中文

- 工作优先级从四级扩展为六级，使六种自动工作可以拥有明确且互不冲突的默认顺序。
- 普通及全能助手默认顺序改为：维修1、补燃料2、炮塔补弹3、保存路线巡逻4、生产投料5、采矿6（最低）。
- 旧版未修改的全能助手设置会自动迁移到新顺序；玩家自定义设置和矿工职业的采矿主业不会被覆盖。
- 同级任务仍会公平轮换，避免玩家主动设为相同优先级的工作互相永久饿死。

### English

- Expanded work priorities from four to six levels so all six automatic jobs can have an explicit default order.
- Normal and Generalist defaults are now Repair 1, Refuel 2, Turret Ammo 3, Saved-Route Patrol 4, Production 5 and Mining 6 (lowest).
- Unmodified legacy Generalist settings migrate automatically; custom settings and the Miner role's primary mining priority are preserved.
- Jobs deliberately assigned the same priority still rotate fairly to prevent starvation.

## 0.15.3

### 中文

- 待机助手继续按个人优先级检查维修、补燃料、炮塔补弹、生产和采矿，只有没有更优先工作时才考虑巡逻。
- 自动巡逻不再生成临时方形路线，只使用该助手亲自保存的巡逻路线，并严格按保存点顺序完成一轮。
- 保存新巡逻路线时会自动以最低优先级开启该助手的巡逻工作；玩家仍可在工作优先级中关闭或提高它。
- 没有保存路线时不会用随机移动代替巡逻，助手会原地等待下一次维修、燃料或其他真实工作检查。
- 每轮巡逻结束后重新评估工作，因此新出现的受损设备或缺燃料设备不会被永久巡逻饿死。

### English

- Idle helpers continue checking repair, refueling, turret supply, production and mining by personal priority, considering patrol only when no higher-priority work exists.
- Automatic patrol no longer generates a temporary square; it uses only that helper's saved route and follows saved waypoints in order for one round.
- Saving a route automatically enables patrol at the lowest priority; players can still disable or raise it in Work Priorities.
- Without a saved route, patrol never falls back to random movement and the helper waits for real work.
- Work is reassessed after every patrol round so new damage or fuel shortages cannot be starved by a permanent patrol.

## 0.15.2

### 中文

- 移除“没有任何可执行工作时随机走动”的强制兜底，助手真正无事可做时会原地待机。
- 普通默认设置和新版全能助手模板默认关闭待机巡逻，避免所有助手长期绕圈乱跑。
- 手动巡逻、保存路线和守卫职业巡逻保持不变；也可以在个人工作优先级中重新开启巡逻。
- 维修、补燃料、炮塔补弹、装备、生产和采矿仍会在发现真实工作后正常移动。

### English

- Removed the unconditional random-walk fallback; helpers now remain still when no enabled work is available.
- Idle patrol is disabled by default for ordinary helpers and the updated Generalist role, preventing constant aimless movement.
- Manual patrols, saved routes and Guard patrol behavior remain unchanged, and patrol can still be enabled in personal work priorities.
- Repairs, refueling, turret supply, equipment, production and mining still move normally when real work is found.

## 0.15.1

### 中文

- 修复普通待机助手只检查随身背包或伸手可及箱子、不会主动走向远处武器箱的问题。
- 安全待机时会优先在个人工作范围内寻找包含可配套枪弹的己方箱子，亲自走过去领取并装入正确的武器与弹药槽。
- 只领取一把所需枪械和最多一组匹配弹药，全部来自真实箱子库存，不会生成装备。
- 自动准备武器属于可暂停的自动工作，不会打断玩家已经下达的手动任务。

### English

- Fixed ordinary idle helpers checking only carried items or immediately reachable chests instead of walking to a weapon supply chest.
- While safely idle, a helper prioritizes a friendly chest within its work radius containing a usable gun/ammunition pair, walks there, and equips the correct slots.
- It takes only one required gun and up to one matching ammunition stack from real stock; no equipment is generated.
- Weapon preparation is pausable automatic work and never interrupts an existing manual order.

## 0.15.0

### 中文

- 常用页新增“一键暂停/恢复自动工作”：暂停时会结束待机调度创建的任务，但保留玩家手动命令、死亡物品找回和遭遇自卫。
- 管理页新增设置复制：选定一名助手后，可把工作优先级、搜索半径、固定工作中心、交战策略和保存的巡逻路线复制给其他助手。
- 新增每名助手独立的防御、均衡和积极三种交战策略，真实影响低血撤退线、无弹药判断及可承受的敌我威胁比例。
- 状态页现在区分自动任务与手动任务，显示前往目标的大致距离，并在助手名称旁显示交战策略。
- 所有新设置均自动兼容旧存档；没有设置过交战策略的旧助手默认使用均衡模式。

### English

- Added one-click Pause/Resume Automatic Work. Pausing stops idle-scheduler jobs while preserving manual orders, death recovery and emergency self-defense.
- Added helper setting duplication for work priorities, search radius, fixed center, engagement stance and saved patrol route.
- Added independent Defensive, Balanced and Aggressive engagement stances affecting health retreat thresholds, unarmed decisions and acceptable threat ratios.
- Status now distinguishes automatic work, shows approximate target distance and displays each helper's engagement stance.
- New settings migrate safely; existing helpers default to Balanced.

## 0.14.1

### 中文

- 修复助手死亡事件中物品已被转入尸体时，记录到空清单而不创建拾取任务的问题。
- 每秒保存一次助手背包、武器、弹药和护甲清单，作为死亡物品识别的可靠兜底；不会复制或生成物品。
- 即使死亡清单为空，助手复活后也会返回死亡点检查自己的尸体和地面掉落物。
- 到达死亡点后最多重试10秒，避免尸体生成时序或暂时背包空间不足导致只扫描一次便放弃。

### English

- Fixed death recovery being skipped when Factorio had already moved possessions into the corpse before the death event was read.
- A lightweight inventory, weapon, ammunition and armor manifest is saved every second as a reliable recovery fallback; it never duplicates or creates items.
- Even with an empty death manifest, a respawned helper returns to the death location and checks the corpse and ground drops.
- Recovery retries for up to ten seconds at the death site instead of abandoning after one scan due to corpse timing or temporarily insufficient inventory space.

## 0.14.0

### 中文

- 新增巡逻小队战斗协同：任意巡逻助手在30格内发现敌人或虫巢时，会呼叫96格内其他正在巡逻的助手共同支援。
- 支援者使用原有战术评估，根据武器、弹药、血量、敌我数量决定接战或撤退，不会获得作弊弹药或伤害。
- 小队会清理发现点周围40格的敌人；战斗或撤退结束后，每名助手恢复各自被中断的巡逻任务和路线点。
- 非巡逻工作的助手不会被强行征召，避免生产、采矿和维护任务被远处战斗频繁打断。

### English

- Added patrol squad coordination: when any patrol helper detects an enemy or nest within 30 tiles, nearby patrol helpers within 96 tiles are called to assist.
- Responders retain normal tactical evaluation based on weapons, ammunition, health and local force balance; no ammunition or damage is created.
- The squad clears a 40-tile area around the sighting. After fighting or retreating, every helper resumes its own suspended patrol route and waypoint.
- Non-patrol workers are not forcibly recruited, preventing distant combat from repeatedly interrupting production, mining and maintenance.

## 0.13.1

### 中文

- 维修助手不再只按当前一台设备领取一个修理包，而会统计个人工作区内可负责设备的总损坏量，一次领取一批。
- 单次最多领取 20 个，并继续受箱子库存和助手背包容量限制，避免搬空共享库存且不会生成物品。
- 成批领取后会连续维修后续目标，显著减少在设备与修理包箱之间来回跑动。

### English

- Repair helpers now calculate a batch from the total eligible damage in their work area instead of collecting for only the current machine.
- A collection trip is capped at 20 packs and remains limited by real chest stock and companion inventory capacity; no items are generated.
- The carried batch is reused across subsequent repair targets, greatly reducing repeated chest trips.

## 0.13.0

### 中文

- 新增多人共享目标调度：维修、补燃料、炮塔补弹和自动采矿会短暂预留目标，避免多名助手同时奔向同一台设备或同一处矿点。
- 目标预留会在完成、失败、取消、任务链中止或目标切换时立即释放；异常残留也会自动过期清理，不会永久卡住工作。
- 长时间采矿和移动途中会持续续约目标；若目标已被另一名助手接手，会自动重新选择工作，而不是互相拥挤。
- 保留个人职业优先级、固定工作区域及最多两人从事同类待机工作的规则，使多助手分工更稳定。

### English

- Added shared multi-companion target scheduling: repairs, refueling, turret ammunition and autonomous mining temporarily reserve their targets so helpers do not converge on the same machine or resource.
- Reservations are released on completion, failure, cancellation, chain abort or target changes; stale claims also expire automatically and cannot permanently block work.
- Long mining and travel continuously renew their claims. A helper automatically selects different work if another helper owns the target.
- Personal role priorities, fixed work areas and the two-helper idle-category limit remain in effect for more stable division of labor.

## 0.12.0

### 中文

- 管理页新增维护员、矿工、守卫、生产助手和全能助手五种一键职业模板，自动配置当前所选助手的自主工作优先级及关闭项。
- 职业模板可应用到单个助手或全部助手，应用后仍可在“工作优先级”中逐项修改。
- 状态页新增“定位所选助手”，在聊天栏生成可点击的地图坐标。
- 状态页新增“停止所选助手”，无需切回常用页即可立即取消其当前任务和队列。
- 工作页新增固定工作中心：框选中心后，个人搜索半径会围绕该位置约束维修、燃料、炮塔、生产、采矿、待机巡逻与闲逛；可一键清除并恢复跟随助手位置。

### English

- Added five one-click roles to Manage: Maintainer, Miner, Guard, Production and Generalist, configuring autonomous priorities and disabled work for the selected companions.
- Roles apply to one or all companions and remain fully editable in Work Priorities.
- Added Locate Selected to Status, producing clickable map coordinates in chat.
- Added Stop Selected to Status, immediately cancelling current and queued work without switching pages.
- Added fixed work centers: the personal radius constrains repair, fuel, turrets, production, mining, idle patrol and wandering around the selected center, and can be cleared with one click.

## 0.11.0

### 中文

- 助手长面板重构为“常用、工作、管理、状态”四个简洁分页，同一时间只显示一组相关功能。
- 常用页集中跟随、镇守、巡逻、保存路线、清敌、停止、补燃料和维修。
- 工作页集中个人优先级与范围、各项数量、路线编辑、建造拆除、蓝图以及采集生产收纳。
- 管理页集中增加/减少助手和装备武器；状态页集中实时工作与失败诊断。
- 语言和指令对象始终显示在顶部；全部原有功能、保存路线、个人设置及旧存档保持兼容。

### English

- Rebuilt the long companion panel into four compact pages: Orders, Work, Manage and Status, showing only one related group at a time.
- Orders contains common movement, combat, repair and refueling commands.
- Work contains priorities, ranges, quantities, route editing, construction, blueprints and production workflows.
- Manage contains companion and equipment controls; Status contains live work and failure diagnostics.
- Language and command target remain permanently visible; all existing features, routes, settings and saves remain compatible.

## 0.10.1

### 中文

- 修复实时状态面板错误读取 Factorio 2.0 中不存在的 `LuaEntityPrototype.max_health`，导致 `on_tick` 崩溃的问题。
- 改为安全读取助手实体自身的最大生命值，并为实时诊断刷新增加隔离保护，面板异常不再中断游戏。

### English

- Fixed an `on_tick` crash caused by the live status panel reading the unavailable `LuaEntityPrototype.max_health` field in Factorio 2.0.
- Maximum health is now read safely from the companion entity, and diagnostic refreshes are isolated so a UI issue cannot stop the simulation.

## 0.10.0

### 中文

- 主面板新增助手实时状态：当前工作、生命值、背包物品总数、排队任务，以及战斗结束后将恢复的原任务。
- 最近五分钟内的任务失败会直接显示在对应助手下方，并限制过长错误文本，便于快速排查助手不动的原因。
- “工作优先级”面板新增每个助手独立的自主搜索半径（32–512格，默认256格）。
- 维修、补燃料、炮塔补弹、生产投料及待机采矿均遵守个人搜索半径，便于把不同助手限制在不同规模的基地或岗位附近。
- 补燃料助手到达箱子后会汇总搜索范围内所有兼容设备的燃料缺口，一次尽量携带整批燃料并连续补充，减少在设备和箱子间来回跑。
- 状态每秒刷新，打开命令面板时立即刷新；旧存档自动获得默认设置。

### English

- Added live companion status to the main panel: current work, health, carried item count, queued tasks, and work that will resume after combat.
- Task failures from the last five minutes appear below the affected companion, with long errors safely shortened.
- Added an individual autonomous search radius (32–512 tiles, default 256) to each companion in Work Priorities.
- Repair, refueling, turret supply, production input and idle mining respect each companion's radius.
- Refueling companions calculate the combined compatible fuel demand in their radius and collect as much of the batch as their inventory can carry, reducing repeated chest trips.
- Status refreshes every second and immediately when the panel opens; existing saves migrate automatically.

## 0.9.25

### 中文

- 巡逻移动启用严格寻路，不再在寻路超时、失败或路径提前结束时朝目标直线行走撞墙。
- 路线暂时不可达时助手会停止并重新请求到同一个巡逻点的安全路径，不会跳点。
- 普通采集、施工和战斗移动保持原有行为，避免扩大改动范围。

### English

- Patrol movement now uses strict pathfinding and never falls back to walking directly into walls after a timeout, failure or prematurely exhausted path.
- When a waypoint is temporarily unreachable, the companion stops and requests a fresh safe path to the same point without skipping it.
- Other mining, construction and combat movement retains its existing behavior to keep the change scoped.

## 0.9.24

### 中文

- 巡逻点与炮塔或建筑重叠时，自动将目的地调整到建筑旁最近的可站立位置，避免助手持续撞向建筑。
- 新建路线会直接保存安全坐标；旧版已保存路线在每次开始时也会自动校正，无需重新绘制。
- 包含 0.9.23 的煤炭优先补燃料改进。

### English

- Patrol points overlapping turrets or buildings are moved to the nearest standable position, preventing companions from continually walking into structures.
- New routes store safe coordinates, while routes saved by older versions are corrected whenever patrol begins and do not need to be redrawn.
- Includes the coal-first refueling improvement from 0.9.23.

## 0.9.23

### 中文

- 自动补充燃料现在优先使用煤炭：先检查助手背包中的煤炭，再优先寻找装有煤炭的己方箱子。
- 没有煤炭或目标设备暂时无法接收煤炭时，才回退使用其他兼容燃料。
- 明确指定燃料的外部命令仍尊重指定类型；不会凭空生成煤炭。

### English

- Automatic refueling now prefers coal, checking carried coal first and then prioritizing friendly chests containing coal.
- Other compatible fuels are used only when coal is unavailable or the target cannot currently accept it.
- Explicit fuel selections remain respected; coal is never created from nothing.

## 0.9.22

### 中文

- 按玩家反馈移除巡逻途中的炮塔自动补弹，避免助手偏离路线并持续挤向炮塔。
- 待机自动补弹及原地镇守补弹功能保持不变。
- 保留严格按保存点顺序巡逻及战斗后恢复当前路线点的修复。

### English

- Removed automatic turret resupply during patrols following player feedback, preventing companions from leaving their route and crowding turrets.
- Idle and hold-position turret resupply remain available.
- Strict ordered patrol routes and post-combat waypoint recovery remain intact.

## 0.9.21

### 中文

- 巡逻助手现在会定期检查路线附近 64 格内的己方弹药炮塔。
- 炮塔低于面板设置的目标弹药数量时，助手会使用背包中的兼容弹药，或从附近己方箱子取得真实弹药后装填。
- 完成一次炮塔补弹后，助手会返回当前巡逻路线点并继续按保存顺序巡逻；遇敌仍优先战斗。

### English

- Patrolling companions now periodically inspect friendly ammo turrets within 64 tiles of their route.
- When a turret is below the configured target, companions use compatible carried ammunition or collect real ammunition from a nearby friendly chest.
- After servicing a turret, the companion resumes the current ordered patrol waypoint; combat still takes priority.

## 0.9.20

### 中文

- 修复自定义巡逻把寻路失败误判为到达、从而跳过路线点的问题。
- 巡逻战斗结束后重新规划到当前路线点的路径，不再错误推进路线序号。
- 自定义及保存路线现在只在助手真实到达当前点后，才按 1→2→3 的顺序前往下一点。

### English

- Fixed custom patrols treating a failed path as arrival and skipping route points.
- After patrol combat, companions rebuild a path to the current route point instead of advancing incorrectly.
- Custom and saved routes now advance 1→2→3 only after actually reaching the current point.

## 0.9.19

### 中文

- 新增“工作优先级”面板，可为每个助手分别设置维修、补燃料、炮塔补弹、生产投料、巡逻和采矿为 1–4 级或关闭。
- 待机助手按个人优先级寻找工作；同级工作定期轮换，避免巡逻等持续可用的工作让其他工作永远无法执行。
- 战斗自卫保持紧急优先，不受普通工作设置影响；玩家手动下达的命令也不受影响。

### English

- Added a Work Priorities panel with per-companion levels 1–4 or Off for repair, refueling, turret supply, production input, patrol and mining.
- Idle companions choose work by their individual settings; equal-priority jobs rotate to prevent an always-available job from starving the rest.
- Combat self-defense remains an emergency override, and explicit player orders are unaffected.

## 0.9.18 — 按损伤取维修包 / Damage-Based Repair Pack Collection

- 助手不再从箱子固定取最多 10 个维修包，而是根据当前受损设备缺失的生命值和每包实际维修量计算本次所需数量。
- Companions no longer take a fixed batch of up to 10 repair packs. The amount is calculated from the current machine's missing health and the actual repair capacity used per pack.

- 每修完一台设备后才为下一台重新计算，避免轻微损坏时占用过多维修包；仍不会凭空生成物品。
- Requirements are recalculated for each machine after the previous repair is complete, preventing excessive pickup for minor damage; items are still never spawned.

- 手动“主动维修”在确认附近没有受损设备后会结束并恢复正常待机，不再长期站在原地等待；新损坏仍会由待机高优先级维修自动处理。
- Manual autonomous repair now ends and returns to normal idle behavior after confirming no damaged machines remain, instead of standing indefinitely; new damage is still handled by high-priority idle repair scheduling.

## 0.9.17 — 战后任务可靠恢复 / Reliable Post-Combat Task Resumption

- 修复主动维修被遭遇战打断后，助手仍等待已经失效的旧寻路请求、杀敌后不返回维修的问题。
- Fixed autonomous repair waiting on an obsolete path request after an encounter, causing companions not to return to repair work after combat.

- 遭遇战开始和结束时会清理被挂起任务的旧寻路状态，战斗结束后从助手当前位置重新规划到原任务目标，保留原任务及进度。
- Obsolete navigation state is cleared when combat interrupts and restores work, so companions re-path from their post-combat position to the original target while preserving the task and its progress.

- 同一恢复机制也适用于补燃料、施工、搬运等使用通用接近路径的任务；巡逻会重新前往战前的当前路线点。
- The same recovery applies to refueling, construction, hauling, and other shared approach-based tasks; patrols re-path to their current pre-combat route point.

## 0.9.16 — 巡逻武器补给与路线保存 / Patrol Armament and Saved Routes

- 巡逻助手没有可用枪械或弹药时，会搜索 256 格内的己方箱子，寻找成套枪械与兼容弹药或当前武器可用弹药，亲自取用、装备后继续原路线。
- When a patrolling companion lacks a usable gun or ammunition, it searches friendly chests within 256 tiles for a complete compatible loadout or ammunition for its current weapon, physically retrieves and equips it, then resumes the same route.

- 完成自定义巡逻路线时会自动保存到每个所选助手的存档记录，切换任务、保存游戏或死亡复活后仍然保留。
- Finishing a custom patrol automatically saves it in each selected companion's persistent record, retaining it across task changes, game saves, and death/respawn.

- 指令面板新增“使用保存路线”按钮，可随时让全部助手或单独助手重新执行各自保存的路线。
- Added a “Use Saved Route” button to restart each selected companion's saved route at any time.

- 枪械和弹药均来自真实背包或己方箱子，不会凭空生成。
- Guns and ammunition always come from real inventories or friendly chests and are never spawned.

## 0.9.15 — 自定义巡逻路线 / Custom Patrol Routes

- 指令面板新增“自定义巡逻”和“完成巡逻路线”按钮，可在地图上按顺序设置两个或更多巡逻点。
- Added “Custom Patrol” and “Finish Patrol Route” buttons for defining two or more ordered patrol points on the map.

- 助手会循环沿自定义路线移动，并在途中自动发现、接近和攻击附近敌人，战斗结束后继续原路线。
- Companions continuously loop through the custom route, automatically detecting, approaching, and attacking nearby enemies before resuming their route.

- 自定义路线支持全部助手或单独助手；也可在最后一个路线点使用右键框选直接完成并开始巡逻。
- Custom routes support all companions or an individual companion; alt-selecting the final point also finishes the route and starts patrol immediately.

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
