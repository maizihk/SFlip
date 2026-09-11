# Windows 交接记录

## 当前任务：W-039 配对码直接连接与自动路由缓存（2026-09-11）

- 分支 codex/windows-pairing-code-connection，协议与批准提案为 PROTOCOL.md / DS-039；schemaVersion、网络字段和硬件状态机时序不变。
- Windows 对完整配置自动监听；已开启且无缓存的配置同样周期发送 null-target 状态探测。收到探测后只按解析后的实际来源地址、端口和配对码唯一匹配，不让旧 endpoint 缓存阻止连接。
- 探测和匹配待处理 event 的响应通过原始报文 HMAC、时间窗及重放校验后自动学习路由。缓存变化在控制线程读取最新配置并先原子保存，再轻量发布路由，仅取消引用旧路由的事件，不重启 USB、DDC 或 UDP；相同缓存幂等，不取消正在进行的事件。
- 设置页不再显示或弹出对端身份确认。用户关闭的配置可学习缓存和回复探测，但保持关闭；错误来源、认证失败、歧义、保存失败及安全状态保持零连接和零硬件动作。
- 自动回归覆盖 null-target 生产构造、旧 target 提示、篡改 target 未重签拒绝、地址/端口/配对码唯一匹配、首次/重装缓存更新、关闭意愿、幂等缓存、精确重复响应及保存失败。完整 Windows 构建和 CI 结果待补。
- 未执行真实网络、USB、DDC、输入源或唤醒操作；双端实机只验证状态连接，仍待用户验收。

## 当前任务：W-038 双端绑定状态不一致的探测回复（2026-09-11）

- 分支 codex/windows-asymmetric-probe，基于 PR #92 的 2b32c01；远端 main 为 f12a224，无遗漏的新主线提交。本分支包含尚未合并的 W-037 前置修复。
- 已确认的代码缺口：带目标身份的 status_probe 只走已绑定协同路由，本机尚未绑定时直接忽略；首次探测处理入口仅允许空目标。修复限制在 Windows 探测路由、诊断与测试，不改 macOS、共享协议、schema、版本或 Release。
- 实机证据限制：两端报告无响应，Mac 已绑定、Windows 未绑定；一次端口计数采集显示有入站而无出站，但未捕获报文内容且不能确认覆盖用户点击，因此不能认定这一个缺口解释全部双向失败。
- 实现（历史边界，已由 W-039 的配对码直连取代）：生产路由 helper 为指向本机且无正常已绑定路由的状态探测选择首次探测处理，保留正常路由、认证与重放校验。异步回复在入口、发送前和解析后复查配置与安全代次；发送日志使用真实返回结果。新增固定白名单收到/匹配/拒绝/发送事件，不含原始信息。
- 验证：已添加生产 helper 与响应函数模拟回归和诊断脱敏检查，git diff --check 通过；本机 x64 Release 在依赖检查处因缺少 64 位 MSBuild 停止，未声称已运行新测试。完整构建、原生回归与安装检查由本次 PR 的 Windows CI 执行，最终结果见 PR。新版本实机双向检测仍待用户验收。

## 当前任务：W-037 Windows 协同离线开启（2026-09-11）

- 基线 main@f12a224，分支 codex/windows-offline-enable。用户要求对端不在线时也能开启；当前阻碍实际是 UI 与保存层均强制先确认对端身份，而非读取实时心跳。
- 允许本机字段完整的 v5 配置先保存开启意愿，身份与协议可保持空值；原配置、字段、schema 和迁移不变。更旧版本不理解已开启的未绑定配置时会沿既有安全失败路径保留原文件，不声称支持无损降级运行。
- 实际目标路由与手动切换入口统一检查已开启、配置完整、v2、唯一非本机对端身份。未绑定开关开启不自动确认身份、不触发切屏或唤醒；既有首次检测、网络权限准备和认证规则不变。
- 设置详情明确显示开启与待确认状态，保存成功时直接更新文本；拒绝真正缺项时列出具体原因。
- 自动回归使用临时配置、模拟时间和状态机，覆盖保存/重载/关闭、拒绝自动绑定、确认后启用、离线无硬件动作、重复身份和安全状态、缺项及保存失败保留。CI 结果以本 PR 为准；本地构建缺少 64 位 MSBuild。
- 实机仍待验证开关及重启保持、两端首次检测确认和长文本布局；只修改 Windows 与本交接，不修改 macOS、协议、配置 schema、版本或 Release。

## 当前任务：Windows v2.3.2 发布（2026-09-11）

- 用户在获取托盘恢复测试包后授权合并 PR #90（e6d7bac），并明确要求更新 Release；发布范围为 Windows v2.3.2 / build 23，macOS 保持 v2.3.0。
- 发布分支 codex/windows-release-2-3-2，只更新 Windows 版本资源、根 README 下载入口、本清单和交接；不改变协议、schema 或硬件行为。
- W-036 修复代码已经通过 431 项原生检查、x64 Release 与 61 项安装器检查；版本更新后的正式产物仍须由发布 PR CI 重新构建验证。
- 本机缺少 MSBuild，发布前从 CI 下载安装版和绿色版，验证应用及安装器均为 2.3.2.23，生成 SHA256SUMS，并以已合并发布提交创建 v2.3.2。
- 未执行新的 Explorer 重启、USB、DDC、切屏或系统设置变更；实机覆盖范围不因发布扩大。

## 当前任务：W-036 Explorer 重建后托盘图标恢复（2026-09-11）

- 现场与根因：SFlip 进程及隐藏托盘宿主仍运行，但 Explorer 的启动时间晚于应用，通知项位置查询失败。正式实现只在构造时 `NIM_ADD` 一次，未处理 `TaskbarCreated`；后续 `NIM_MODIFY` 失败也不会重新添加，所以 Explorer 重建后进程继续运行而托盘入口消失。
- 修复：隐藏窗口注册并处理 `TaskbarCreated`，按当前 DPI/主题重绘图标，以完整字段先 `NIM_MODIFY`、缺失时 `NIM_ADD`，成功后恢复 `NOTIFYICON_VERSION_4`。状态、气泡和主题图标修改失败也进入相同恢复路径。
- 生命周期：首次恢复立即执行，失败后每 500 ms 重试，最多 8 次；重复广播不会重置正在进行的次数或延后定时器，成功、耗尽和析构都会停止。退出 guards 与定时器清理由静态审核确认，自动测试不声称覆盖真实窗口析构或迟到 `WM_TIMER` 集成。
- 自动验证：代码提交 `1077018781e08ab60a97253b2200f997a664bf69` 已通过 [Windows CI run 34577968101](https://github.com/maizihk/SFlip/actions/runs/34577968101)：x64 Release 构建和 431 项原生检查（构建内与显式复跑各一次）、1.90 MiB framework-dependent 分发校验、61 项安装器生命周期检查、独立安装器冒烟及两个 artifact 上传全部成功。纯模拟直接调用生产恢复 helper，覆盖 MODIFY 成功不 ADD、丢失后 ADD、SETVERSION 失败后仅 MODIFY 既有项、Shell 持续失败上限和最终版本失败仍保留已有项。测试不访问真实 Shell、USB、显示器、网络或系统设置。
- 本机构建阻塞：`Windows/build-windows.ps1 -Architecture x64 -Configuration Release` 在第 32 行失败，系统缺少 64 位 MSBuild、Visual Studio C++ 桌面开发和 Windows App SDK C++ 组件；完整编译、原生测试和分发校验以 PR CI 为准。
- 实机待验：Explorer 重启后自动恢复、主显示器 DPI/主题变化广播、恢复期间退出。任务未重启 Explorer 或 SFlip，未执行真实 USB、DDC、输入源、唤醒、网络或系统设置操作。
- 范围只含 Windows 正式 C++ 实现、原生模拟测试、Windows 清单与本交接；不修改协议、配置 schema、macOS、版本、tag 或 Release。

## 当前任务：Windows v2.3.1 发布（2026-09-09）

- 用户确认重新绑定修复测试通过并授权合并，PR #88 已合并至 25ad9e7；随后明确要求更新 Release。
- 发布分支 codex/windows-release-2-3-1，Windows 版本 2.3.1 / build 22；macOS 保留 v2.3.0 下载，不改其代码或版本。
- 修改 Windows 版本资源、根 README 下载说明、Windows 清单和本交接记录；不改变协议、配置或硬件行为。
- 本机缺少 MSBuild，发布构建由 Windows CI 执行；发布前必须验证原生测试、x64 Release、安装器检查、两种分发文件版本和 SHA256。最终结果见发布 PR 与 v2.3.1 Release。
- 用户实机验收只代表本次反馈场景，不代表全部 DP/扩展坞/同名显示器或高 DPI 组合已验证；本次发布不执行硬件操作。


## 当前任务：W-002 显示器显式重新绑定（2026-09-09）

- 分支 `codex/windows-display-rebind`，PR [#88](https://github.com/maizihk/SFlip/pull/88)，基线 `origin/main@445aab9cbdc1e70e7b1500b519b8f0be9e793ee9`。代码提交 `da63cbb270ae15cd4fccd1e1724a51b37d8ed671` 已通过 [Windows CI](https://github.com/maizihk/SFlip/actions/runs/34333247960)：426 项原生检查、x64 Release、1.89 MiB 分发校验、61 项安装器生命周期检查及独立安装器冒烟全部通过；安装版与绿色版 artifact 已上传。后续仅补记此验证结果，不改代码。初始进入待确认的原因尚未确定；已确认的产品缺陷是待确认目录没有恢复入口，且诊断把待确认误报为离线。
- 设置页为显示器目录提供“重新绑定”。候选不默认选择，只来自当前本地可信拓扑，并要求持久强身份、逻辑 target、拓扑 generation 和单物理句柄可唯一复核，且未被其他逻辑目录占用；确认时重新枚举，连接状态变化即拒绝。
- 成功改绑只替换物理身份，保留逻辑显示器 ID、功能开关及 USB/协同输入映射；物理身份变化会清空亮度、对比度、音量的旧值与上限，避免媒体键消费另一台显示器的缓存。保存通过既有原子持久化回调，失败或异常恢复旧配置。
- `NormalizeDdcMonitorCollection` 不再把零物理句柄改写为一个，零/多句柄都保持不可操作。诊断将 `NeedsConfirmation` 显示为“安全拒绝（待确认）”，不再显示“不可用（离线）”。
- 模拟测试新增候选/确认、零与多句柄、重复强身份、重复逻辑 target、其他目录占用、取消、重新枚举/保存异常、拓扑代次或身份变化、成功提交和逻辑映射保留覆盖；未访问真实 USB、DDC、输入源、网络、唤醒或系统设置。
- 本机构建阻塞：`pwsh -File Windows/build-windows.ps1 -Architecture x64 -Configuration Release` 在脚本第 32 行失败，明确报告缺少 64 位 MSBuild、Visual Studio C++ 桌面开发和 Windows App SDK C++ 组件。编译、自动测试与 dist 打包需由 PR CI 验证。
- 实机待验：DP 待确认条目选择并保存、重启后保持、拔插期间安全取消、同名显示器候选可辨识、高 DPI/窄窗口按钮布局。此任务不声称已经确定 DP 条目最初进入待确认状态的原因。
- 范围只含 `Windows/` 和本交接文件；未修改 macOS、协议、contracts、schemaVersion、版本、workflow、tag 或 Release。
## 当前任务：v2.3.0 正式发布（2026-09-07）

- 用户确认已经实机测试，明确授权正式发布；基线 `main@28de478`，分支 `codex/macos-release-2-3-0`。
- 双端版本统一为 2.3.0 / build 21；README 下载入口更新为 DMG、macOS ZIP、Windows Setup EXE、绿色版 ZIP 和 SHA256SUMS。
- 仅修改版本资源与发布文档，协议、配置与应用行为不变。版本构建及 Release 校验以本任务 PR 和 v2.3.0 Release 为准；此前 PR #86 双端 CI 均通过。
- 用户实机确认不代表覆盖全部硬件组合；本次代理不执行真实硬件动作。

## 当前任务：W-101/W-102 分发文案简化（2026-09-06）

- 在 `codex/windows-installer` / PR #86 的 `3cc1090` 基线上继续，远端 main 为 `bad06b4`；用户明确授权双端清理。
- 删除关于页、安装说明和公开文档中的签名状态提示，新构建附件按产品、平台、架构和格式命名；保留历史 Release URL 与构件标识，避免失效。
- 构建签名与校验、运行库检测、安装和升级行为不变；无协议、schema、版本变更。
- 验证：平台自动测试与 Release 打包正在执行，最终结果以 PR #86 检查为准。未启动应用或执行硬件流程；关于页显示、安装与首次启动仍待实机验证。

## 当前任务：W-101 Windows 安装器中文化与外部依赖检测（2026-09-06）

- 分支 `codex/windows-installer`，在未合并 PR #86 / `963de1f` 上继续。用户要求中文安装、不内置运行库，缺少时提醒自行下载安装；签名继续延期。
- 安装器切换为 x64，提供简体中文/英文，按系统界面语言选择并允许手动切换；安装说明、缺依赖、降级拒绝、桌面入口和卸载显示名均本地化。
- 删除微软运行库下载与捆绑。复用应用 Bootstrap DLL 调用 `MddBootstrapInitialize2` 检测当前用户可加载的兼容运行库；版本参数依据 SDK 2.4.0 头文件，构建检查 SDK pin。每次重试重新检测；失败不复制文件，仅经用户选择打开微软官方 x64 下载链接；静默安装不打开浏览器。
- 保留原安装目录、开始菜单/可选桌面入口、配置、登录启动清理和运行 mutex 行为。安装包限制小于 20 MiB，生成 SHA-256。协议、schema、版本和应用业务代码不变。
- 修改：Windows 安装脚本、`installer/SFlip.iss`、中英文安装说明、模拟 Bootstrap 生命周期测试、Windows workflow、根/Windows README、本平台清单与交接。
- 验证：前一提交已通过原生 416 checks、x64 Release 和 49 项旧安装回归。当前双语提示、Bootstrap ABI/失败关闭及全部安装生命周期由 PR #86 新 CI 执行，以最终 checks 为准；测试不启动真实应用、网络下载或硬件流程。
- 实机待验：中文系统默认语言、真实缺失/已安装依赖、浏览器下载后重试、首次启动及登录启动。未改变本机权限、防火墙、签名信任或真实硬件状态。

## 当前任务：W-035 SFlip 对外命名统一（2026-09-06）

- 分支：`codex/macos-dmg-packaging`，在 PR #84 已完成的 DMG 基础上继续，改名前基线 `0285071`。用户明确授权双端对外名称统一；协议、schema 和版本不变。
- Windows 产品元数据、关于、托盘、诊断、启动器和 CI 附件统一为 SFlip；登录启动选择新入口，原配置目录、Run 注册项和 runtime 文件名保留。完整原生测试、x64 Release、分发校验由本次 PR Windows CI 执行，以 checks 为准。
- README 保留旧 Release 下载链接，补充旧名升级与登录启动重新确认步骤；未更名 GitHub 仓库或历史记录。
- 待实机：旧版升级、权限复用、快捷方式和登录启动；未安装/启动应用或执行硬件流程。

## 当前任务：W-204 / W-034 审核修复（2026-09-06）

- 分支：`codex/macos-windows-audit-fixes`；基线：`8179ea2`。本次为用户授权的双端审核修复，不修改协议、公共合同、schema、版本或工作流。
- 根因：入站请求替换事件却继承旧出站计时器；媒体键成功写入后保留待写值，后续滑杆调节被旧投影覆盖。
- 修复：切换事件前取消旧计时器；成功写入清除匹配投影并保留更新待写值；规划时在同一锁边界读取最新缓存，避免同一批事件消费过时快照。
- 新原生回归覆盖滑杆更新后的加音量、旧完成保留新投影，以及重叠请求/延迟唤醒只回复 ready、等待 committed。
- 本机纯 C++ 模拟结果：滑杆设 80 后加音量为 85；入站事件不再重发为出站请求，600 ms 不再错误切屏。该模拟不替代 Windows 平台验证。
- 完整 x64 Release、原生测试与 dist 校验由本次 PR 的 Windows GitHub Actions 执行，以 PR checks 为验收记录。
- 待实机：连续媒体键与托盘滑杆交错、双向请求重叠；未执行真实网络、DDC、USB、唤醒或输入源动作。

## 当前任务：W-034 Windows 后台媒体键 DDC 路由与待验修复集成

- 日期：2026-09-04。综合分支 `codex/windows-media-keys-integration` 从 `origin/main@975b469` 建立，按原提交顺序保留 PR #74 单色通知图标、PR #75 冷启动输入源动作前刷新（用户已实机确认）和 PR #76 托盘退出图标/DDC 行紧凑化；旧 PR 保持开放，不改写历史。
- 根因：正式 Windows 实现此前没有后台媒体动作入口；托盘隐藏 HWND 只处理 Shell、主题、显示拓扑和 WTS 消息。直接监听 Fn/OEM F 键既不通用，也可能吞掉或重复系统行为。
- 事件边界：新增 `MediaKeyWatcher`，用 `RIDEV_INPUTSINK` 观察标准音量键盘 VK 及 HID Consumer Control 的标准音量/亮度 usage；不设置 `RIDEV_NOLEGACY`，不监听 Fn/F 键、不猜 OEM 键码、不用低级 hook。30ms 内相同动作的键盘/HID 跨来源双上报只分发一次，同来源或超窗重复继续支持长按。无标准亮度事件的设备自然不支持。
- 路由语义：每次动作在后台强制刷新当前物理拓扑和句柄租约。关闭联动时，对全部启用对应功能、在线唯一解析且有可信值的显示器做相同步进 5；开启联动时只从确定的公共值生成一个绝对目标，混合/未知零写入。静音按显示器保存当前配置 generation 内的最近非零值，配置重载/安全重置/退出后不恢复旧值，未知/不支持不写。
- 安全与生命周期：动作计划复用 `DdcWriteQueue` latest-wins、`DdcControlService` 一次刷新重试/最终 RDP gate、side-effect generation、取消和 action-time config；失败清除乐观值，配置变化、拓扑变化及退出清理待处理事件。Raw Input 只观察，Windows 原生媒体行为继续发生。
- 纯 fake 测试已加入标准音量/亮度事件、释放和非标准键拒绝、重复、联动/非联动、混合/未知、部分未知/离线、RDP/不可信、generation、失败基准与静音恢复。本机 macOS 无法运行 Windows x64 Release；综合 PR #78 / Windows run `33823153891` 已通过 x64 Release、411 checks、framework-dependent 分发校验和 artifact 上传。
- 综合交付：分支 `codex/windows-media-keys-integration`，提交 `aeda6014f0b2238f8ef78705e07ea307cdd1aed6`，PR #78；artifact `DisplaySwitcher-Windows-x64-unsigned-framework-dependent`（ID `9919244404`，9 文件、902507 字节，下载 ZIP SHA-256 `b9010cdb194af1aa236420efcb0f90a934bc5a1dcfcfe44ab945d3b7766297c5`）。PR 保持开放，状态 MERGEABLE/CLEAN。
- 不修改 macOS、`PROTOCOL.md`、共享合同/schema 或版本号；未执行真实 DDC、USB、网络、唤醒或输入源动作。
- 实机待验：不同键盘标准媒体事件、按住重复、原生 Windows 行为不受影响、两屏相对步进/联动/静音、RDP/会话切换，以及 #74/#76 的托盘视觉。

## 上一任务：W-033 Windows 托盘菜单图标与 DDC 行紧凑化

- 日期：2026-09-03。原分支：`codex/windows-tray-menu-polish`，堆叠基线：`origin/codex/windows-monochrome-tray-icon@0ebaccc`（PR #74）；综合分支同时保留 PR #75 的 W-032 冷启动修复。
- 根因：退出项使用 `E8BB` 关闭 X，而其他项均为常规 Fluent/MDL2 语义图标；DDC 标签列固定 64 像素、间距固定 8 像素且含滑杆时强制 272 像素目标宽度，短标签浪费空间而长标签仍可能裁切。
- 实现：退出项改为同一图标字体、16 像素字号和正常字重下的 `E7E8` 标准电源图标；不再有退出项专属放大或粗线。DDC 行分别测量普通文本和滑杆标签，标签列取实际最宽名称且最小 32 像素，滑杆间距缩为 4 像素，菜单以 260 像素（96 DPI）为统一最小视觉宽度并按内容扩展。
- 安全范围：只改变托盘自绘菜单的字形与几何；未修改 Shell 单色通知图标、托盘命令、DDC 投影/写入、USB、网络、设置窗口、协议或持久配置。
- 自动验证：纯生产布局测试覆盖电源字形、短/长标签、中文名称、混合/三位数值空间和 100%/125%/150%/200% DPI；综合 PR #78 / run `33823153891` 已通过 x64 Release、411 checks 和分发校验。
- 快捷键审计结论已转入综合分支的独立实现任务；不监听 Fn/OEM F 键，不使用低级键盘 hook。
- 实机待验：暗/亮菜单、100%/125%/150%/200% DPI、长显示器名称，以及电源图标与系统菜单项的视觉重量；不执行真实 DDC 或快捷键动作。

## 上一任务：W-032 冷启动后首次输入源切换

- 用户实机复现：退出旧测试版后启动新版，首次手动切换有一台物理显示器不切换；关闭再开启 USB 切换后恢复。
- 根因不在 USB 开关本身：输入源动作直接消费启动时的单次物理拓扑运行态和同一组 DXVA2 句柄租约。若进程交接期一台屏暂时未解析，它会被本次动作跳过；USB 开关仅因触发 `ApplyConfiguration` 重新枚举而表现成“修复”。
- 修复为动作前重规划：手动协同与 USB 离开都在实际写入前获取一次 fresh 物理拓扑；同指纹强制枚举替换 DXVA2 句柄租约但不改变 topology generation。
- fresh 结果只修正本次 action config 的运行态绑定，不替换 `config_`、不写 `settings.json`。本地权威快照内单台离线/歧义/缺映射只隔离该屏；RDP/虚拟、部分、空或失败快照整体零写入。
- USB 观察从读取配置、枚举、协调器决策到批处理共用同一 side-effect generation；配置重载发生在枚举中时，过期计划在首屏前零写入，发生在多显示器写入中途时则在下一目标前停止。
- 纯 fake 测试覆盖过期冷启动绑定恢复且零持久化、USB 开关无关性、两屏单屏离线隔离、RDP/不可信零写入、配置并发停止及句柄租约刷新决策。
- 本分支不修改 macOS、共享协议、contracts、schemaVersion 或版本号。
- 首轮自动验证：GitHub Actions Windows run `33722780439` 成功；x64 Release 构建/打包、363 checks、framework-dependent 分发校验和构件上传全部通过；枚举代次门控由综合分支最终 CI 继续验证。
- 分支 `codex/windows-cold-start-display-switch`，提交 `b1eee32ce87572ffea242298c8ef780a25a3f9c4`，PR #75；构件 `DisplaySwitcher-Windows-x64-unsigned-framework-dependent`（artifact `9881133096`，SHA-256 `35d48edf18c1729836e0e11deb7c2abe5e5bc05d3a5722910873ee89e3ca2a3b`）。
- 用户已实机确认冷启动刷新修复通过；综合 PR #78 / run `33823153891` 已重新通过 Windows x64 Release、411 checks 与分发校验。两屏部分失败和 RDP 返回本地仍待专项实机；自动测试未执行真实 DDC、USB、网络或唤醒。

## 上一任务：W-031 Windows 通知区域自适应单色图标

- 日期：2026-09-03。分支：`codex/windows-monochrome-tray-icon`，基线：`origin/main@975b469`，已包含 PR #72/#73。
- 根因：托盘宿主此前直接把彩色 `AppIcon.ico` 资源交给 Shell，应用图标与通知区域图标没有边界，也没有任务栏主题、DPI 刷新或自有 `HICON` 生命周期。
- 实现：新增可复现的软件渲染模块，只为 Shell 生成透明的黑/白“显示器 + 百分号”线稿；按用户实机反馈将主体从 88% 调整为占 90% 图标槽，统一笔画保持主体的 6%，100% DPI 仍为约 0.84 像素的抗锯齿视觉线宽。`AppIcon.ico` 及 EXE、设置窗口、任务栏应用图标不变。
- 主题与刷新：颜色读取系统任务栏 `SystemUsesLightTheme`，高对比或读取失败按系统背景亮度选择高对比 fallback；主题、系统颜色或 DPI 改变时，仅当渲染状态变化才用一次 `NIM_MODIFY` 替换现有通知项。
- 资源安全：动态 `HICON` 只在 Shell 接受替换后接管，旧自有句柄随后销毁；失败恢复旧句柄，析构和构造失败均释放自有资源，共享 fallback 不销毁。
- 自动验证：纯测试覆盖 light→black、dark→white、未知 fallback、16/20/24/32 像素透明边界与约 10% 光学留白、黑白预乘 alpha、可见/alpha 覆盖率上下界、重复相同状态不刷新及主题切换一次更新。90% 主体、6% 笔画已由综合 PR #78 / run `33823153891` 通过 x64 Release、411 checks、分发校验和 9 文件 artifact 上传。
- 实机待验：浅/深色任务栏、高对比、展开/折叠区，以及 100%/125%/150%/200% DPI 的清晰度与无闪烁切换。

## 上一任务：DS-028 / DS-029 / W-030 托盘、离线目录与 USB 冷启动

### DS-028 已实现

- 托盘 USB 状态只显示持久化开关语义；设备身份不再进入可见菜单。RDP、安全模式、学习和拓扑信任只进入既有运行门控，不改变“配置是否开启”的文案。
- 所有非分隔菜单项都有语义图标，图标字体不可用时安全退化；菜单几何由同一 DPI/内容布局模型计算；W-033 进一步把 96 DPI 最小视觉宽度统一收紧为 260 像素。
- 左右键、双击和键盘激活都只打开同一个托盘菜单；设置窗口只从明确的“设置…”命令打开。
- 设置窗口复用现有实例，打开时恢复、激活并请求前台，没有 topmost 或失焦隐藏行为。
- 新增纯模型回归覆盖 USB 文案、托盘激活路由、紧凑宽度、DPI 缩放和滑杆最小可操作宽度；Windows Release 与实机视觉结果待本分支最终 CI 统一记录。

### DS-029 已实现

- “重新检测显示器”仍只更新目录状态；不会自动删除任何持久显示器或映射。
- 删除按钮仅投影最近本地权威、非空拓扑中明确 `Offline` 的条目；远程/镜像/失败/空/部分检测既不显示也无法通过确认回调执行。
- 删除在候选配置中级联目录、USB 映射、全部协同映射及该目录自带的 DDC 缓存/托盘偏好；原子保存成功后才替换工作配置，失败保留旧配置。
- 删除最后有效映射会关闭对应 USB/协同能力；其他有效映射继续工作。该路径不调用任何硬件或网络接口。
- 纯模型测试覆盖本地/远程/不完整信任、在线拒绝、部分映射保留、最后映射停用和候选回滚；Windows Release 与实机 UI 待最终 CI 统一记录。

### W-030 已实现

- 根因是启动顺序与代次竞态：watcher 先以空绑定启动，ApplyConfiguration 又在协调器准备前重配，且旧 presence 回调无法区分配置代次；手动切换 USB 开关只是强制产生了新的观察。
- 现在控制器先用当前配置和拓扑信任更新协调器，再为同一个 watcher 发布新 generation；回调只在 generation 仍为当前值时进入协调器，读取中发生重配的旧结果直接丢弃。
- 冷启动后的第一次当前代次观察只建立基线；同绑定 reload 保留基线，换绑或从不可信拓扑恢复则重新建立基线。没有模拟 toggle、定时重开或第二个 watcher。
- RDP/远程/镜像/空/部分/失败拓扑及安全配置在协调器层为安全态，最终硬件层既有门控继续保留；纯模型验证初始零副作用和之后真实变化才产生动作。
- 模拟覆盖 enabled/disabled、设备初始在/不在、拓扑先/后、过期 generation、重复初始化、配置 reload、换绑和部分映射；完整 Windows Release/CI 与实机冷启动待本分支最终记录。

## 上一任务：DS-027 联动 DDC 统一控件

- 日期：2026-09-02。分支：`codex/windows-linked-ddc-unified-controls`，基线：`origin/main@b7d2cc9`。
- 根因：旧 `LinkAllDisplays` 只传入 `DdcControlService::Write` 扩大写目标；`SettingsWindow::RebuildDisplayEditors` 和 `BuildDdcTrayControls` 仍分别按显示器投影，最终写入入口也没有根据全部目标上限做批量预检。
- 实现：新增设置页和托盘共用的纯 `DdcProjectedControl` 投影。关闭联动保留逐显示器结构；开启后每个已启用功能只显示一个公共滑杆，每台显示器的功能/托盘开关、读取按钮和状态继续保留。
- 值语义：全部目标同值才显示数字；不同值显示“混合”，任一目标缺值显示“—”。设置页与托盘在用户首次调节前不显示代表某台具体值的 thumb；首次调节后向全部合格目标写相同绝对值，不取平均。
- 安全边界：公共上限取各目标有效上限最小值，未知按 100；超界批量预检后零 transport 写入。投影只纳入当前本地权威拓扑中已启用、在线、唯一解析的物理显示器；`DdcControlService::Write` 再次硬拒绝 RDP/不可信拓扑和超界值。
- 托盘：联动开启后按亮度/对比度/音量扁平投影，最多三项；任一已配置显示器启用功能且勾选托盘即显示，写入时目标为所有已启用该功能的合格显示器，不只限于勾选托盘者。
- 保留：未改动输入源独立后端、USB/网络/协议、保存反馈作用域、latest-wins、一次刷新重试、取消、generation 和部分失败隔离。
- 自动验证：PR #71 Windows CI run `33609057399` 全绿；x64 Release 成功，完整原生测试通过 334 checks，framework-dependent 分发校验和 artifact 上传成功，绿色版目录 1.82 MiB。全部新场景使用 fake，未执行真实 DDC、USB、网络、唤醒或输入源。
- 实机待验：多显示器滑杆值/上限、混合/未知视觉与辅助功能、托盘结构、部分失败以及 RDP 返回本地后恢复。

## 当前任务：输入源 null/零值安全与 USB 保存回显

- 日期：2026-09-02
- 分支：`codex/windows-ui-alignment-fix`，继续更新现有 PR #69，没有覆盖该分支已有 UI、拓扑投影或重复绑定修复。
- 根因：输入框、v5 解析、运行时映射和原生输入源传输此前都接受 `0`，因此上层遗漏时可能最终调用 `SetVCPFeature(0x60, 0)`；USB 保存仍使用无反馈作用域，与协同页的底部持久化反馈不一致。
- 数据与迁移：统一输入源为 `null` 或 `1...65535`。旧 v5 USB/协同零值原子迁移为空映射；迁移后全空会关闭相关功能，迁移写入失败保留原文件、写安全标记并进入零副作用安全状态。协同配置允许部分显示器为空，但至少需要一台当前显示器具有有效映射。
- 多层安全边界：设置解析和配置校验拒绝显式零/负数/非数字/溢出；选择器、Controller 与 USB 协调器将空或非法值报告为 `missing_mapping` 并继续其他有效显示器；输入源服务在调用 transport 前拒绝；`NativeInputSourceTransport` 在锁、显示器解析和 DXVA2 调用前再次拒绝，确保零值不能到达 `SetVCPFeature`。
- UI：USB 与协同分别保存自己的底部反馈。只有实际修改且成功持久化才显示绿色“✓ 已保存”；切换标签、切换正在编辑的协同配置或重载只清除短暂成功，不清除失败；网络检测、USB 学习过程、DDC、输入源及其他非保存操作不触发或覆盖保存反馈。
- 共享契约：`specs/proposals/DS-026-input-source-null-safety.md` 已于 2026-09-02 批准；公共 USB schema 的映射和 `switchDisplay` 动作范围已收紧为 `null` 或 `1...65535`，双端缺失映射继续使用 `missing_mapping`，不新增 `invalid_mapping`。本次未修改 `PROTOCOL.md` 或 macOS 源码。
- 本机验证：Windows 实现提交 `bf0d8f8` 已有 `Windows/build-windows.ps1` x64 Release、316 checks、v2 公共向量 1+4+20+6 和 USB-001 至 USB-016 全部通过的既有证据，绿色版目录 1.78 MiB。本次共享合同更新在 macOS 环境执行合同检查和 `git diff --check`，未重复运行 Windows Release，不把既有结果冒充为本轮结果。
- 自动测试边界：使用临时配置和模拟 USB/DDC/输入源，覆盖空白、1、65535、0、负数、非数字、溢出、null 回显、旧零值迁移、迁移写失败、全部为空、部分映射、USB/手动/协同共用执行路径、原生最终边界和保存反馈作用域。未访问真实网络、USB、DDC、显示器唤醒或输入源。
- 实机待验：USB/协同输入框留空与非法值回滚；部分映射只切有效显示器；USB 与协同底部反馈的颜色、两秒隐藏和失败保持；不在本任务中执行真实输入源切换。
- 实现提交：`bf0d8f80553019415dc7cf74c07a47349a400a7a`。
- PR：[#69](https://github.com/maizihk/DisplaySwitch/pull/69)，保持 open，不自行合并。
- CI：最终推送后只读 API 确认 PR #69 为 OPEN、MERGEABLE/clean，包含上述实现提交，base 仍是堆叠分支 `codex/windows-rdp-display-topology`。Windows workflow 只对 `main` base 运行，因此当前没有 GitHub check 或 workflow run；本节 316 checks 与 Release 是 Windows 本机验证，不冒充 GitHub 托管 CI。

## 当前任务：Windows RDP 会话显示拓扑安全

- 日期：2026-09-01
- 分支：`codex/windows-rdp-display-topology`
- 堆叠基线：`origin/codex/windows-input-source-transport@12fb328188a2ccd5c538859189ff48377f2d2fe5`；该基线包含 PR #66 的 W-206 完整实现，因此没有从尚未包含它的 `main` 重做或丢弃堆叠提交。
- 根因：原生枚举把当前会话的 `QueryDisplayConfig` / `EnumDisplayMonitors` 结果直接视为可持久协调的本地物理拓扑；RDP 虚拟目标可能因此新增到显示器目录，而 `ERROR_ACCESS_DENIED`、部分或空结果也缺少明确的可信度语义。
- 设计：新增本地物理权威、远程会话受限、不完整/不可用三态可信度；持久物理目录与实时会话拓扑分离，只有完整非空的本地权威快照可以调用显示器协调并保存。
- 远程识别：使用 `SM_REMOTESESSION`，并结合当前进程 session 与 `GlassSessionId` 处理 RemoteFX/vGPU 场景；同时按 `DISPLAY_DEVICE_REMOTE` 和 `DISPLAY_DEVICE_MIRRORING_DRIVER` 标志处理目标，不使用名称、品牌或型号黑名单。
- 安全行为：远程或不可信快照不新增、删除、重命名或重新绑定显示器，不修改稳定 ID、native 绑定、generation、USB/协同映射，也不保存配置；普通 DDC 和输入源传输在解析前阻断。诊断只输出 `local-authoritative`、`remote-limited` 或 `incomplete-unavailable`。
- 恢复路径：保留 `WM_DISPLAYCHANGE` 的现有失效机制，并在托盘隐藏窗口注册 WTS 会话通知；返回本地控制台后重新枚举，仍只按强身份恢复一对一绑定。
- 自动测试：模拟本地 3 台物理显示器→RDP 单虚拟目标→本地 3 台重排恢复，覆盖远程/镜像标志、首次 RDP 启动、访问受限、枚举失败/空/部分结果、目录和全部映射不变、零保存及零 DDC/输入源调用。
- 本机验证：`Windows/build-windows.ps1` x64 Release 成功，完整原生测试通过 262 项检查；v2 公共向量 1+4+20+6、USB-001 至 USB-016 及既有 DS-004/005/007/009/012/013、W-005/W-203 回归全部通过。自动测试没有连接真实 RDP，也没有访问真实显示器、USB、网络、唤醒或输入源。
- 产物验证：绿色版目录 1.75 MiB，入口、`runtime/` 和必需文件完整，低于 20 MiB。
- 实机待验：连接 RDP 时设置页保留原物理目录且无虚拟条目；断开 RDP 返回本地后稳定 ID、名称、DDC/托盘开关、USB/协同映射恢复；随后经用户授权验证 DDC 和输入源仍指向正确物理显示器。
- 实现提交：`72d319fca369b91cf837fb57baa229fe23ece465`。
- PR：[#68](https://github.com/maizihk/DisplaySwitch/pull/68)，base 为 `codex/windows-input-source-transport`，保持 open，不自行合并。
- CI：当前 Windows workflow 只监听以 `main` 为 base 的 PR，堆叠 PR #68 因此没有 GitHub check；262 项检查和 x64 Release 均为本机验证，不冒充 GitHub 托管 CI。待上游 PR #66 合并并将本 PR 改为 `main` 基线后再执行最终云端验证。

## 当前任务：Windows USB/协同 UI 信息架构与保存反馈对齐

- 日期：2026-09-01
- 分支：codex/windows-ui-alignment-fix
- 基线：已 fetch 并确认包含 Windows 最新提交 26aef485cec15e8db175cff9fc4db50c035ddec4。
- 范围：仅 Windows 原生设置窗口、Windows 自动测试和 Windows 清单；不修改 macOS、PROTOCOL.md、共享协议、schema、版本、tag 或 Release。
- 根因：USB 与协同页面仍按旧的多卡片信息架构组织；协同详情通过 CreateCard 再包一层；保存、检测和设备操作共享同一 validation_ 文本，导致成功使用错误颜色、首开/操作反馈污染及保存状态不自动消失。
- 实现：USB 页现在只有“自动切换”和“联动协同”两张外层卡片，对端输入源映射位于自动切换卡片的分隔段；协同页只有“协同状态”和“配置”两张外层卡片，当前配置选择、编辑字段、映射、触发设备引用和删除操作位于同一配置卡片。
- 保存反馈：新增独立 SettingsSaveFeedback 与底部固定状态区域；仅实际配置变化且成功持久化后显示绿色“✓ 已保存”，使用可取消并重置的 2 秒计时；失败显示语义红色且保留到下一次成功。网络、USB、DDC、输入源和诊断提示走独立操作状态。
- 测试：新增纯模拟契约测试，覆盖两个页面的卡片数量/顺序、无嵌套卡片、0/1/3+ 显示器、Star 输入+固定尾部开关、底部非滚动保存提示、首次无保存反馈、成功隐藏、连续保存重置、失败保持和非协同操作隔离。完整 DisplaySwitcher.Tests.exe 实际通过 285 checks；未使用真实 sleep、网络、USB、DDC、输入源或显示器。
- 构建：pwsh -File Windows/build-windows.ps1 -Architecture x64 -Configuration Release 已成功编译原生应用、启动器和测试并运行完整测试；完整 dist 打包成功，绿色版目录为 1.76 MiB。构建日志仅有受限网络下 NuGet 漏洞元数据的 NU1900 警告，缓存依赖、编译、测试和打包均成功。
- 实机待验：浅色/深色、高 DPI 与窄窗口下的两页布局及长配置名；0/1/3+ 实际显示器映射；真实保存反馈可见性；不在本任务中执行真实 USB、DDC、输入源、唤醒或网络操作。
- PR #69 P1 后续：修复 UsbDeviceRow 重复接收 usbDeviceStatus_ 的所有权错误，状态元素现只挂载到独立“当前状态”行。SettingsSaveFeedbackScope 明确定义 None/Collaboration 边界；常规、USB 和显示器保存使用 None，协同字段、配置增删和协同检测持久化使用 Collaboration，非协同保存不会显示或清除协同保存状态。新增契约测试覆盖单一状态容器和非协同保存隔离；完整模拟测试、x64 Release 与 dist 打包通过 287 checks。
- PR #69 第二轮审核根因与修复：网络权限回调原先无条件按失败展示，现按 `ready` 显式选择成功/失败 severity；USB 学习结束原先所有文案都进入 `failure=true`，现使用 `UsbLearningCompletion` 区分成功、取消、超时、失效和失败；保存失败路径原先直接刷新状态而未停止仍在运行的成功计时器，现由生产保存 Presenter 标记计时器停止并同步停止 WinUI timer。
- PR #69 生产布局验证：删除仅供测试读取的配置名称、底部状态和 USB 状态行自证常量。`SettingsWindowLayoutPresenter` 由 `BuildContent()` 的真实挂载入口消费，重复 USB 状态父节点或错误的协同保存反馈区域会在进入 WinUI 前拒绝；USB/协同两页卡片模型仍由生产构建消费。
- PR #69 UI 冒烟：x64 Release 包通过 `--show-settings` 实际打开设置窗口，依次进入“USB 切换”和“协同”。两页均成功构建、非空、无崩溃；USB 页显示“自动切换/联动协同”两张主卡片，协同页显示“协同状态/配置”两张主卡片，配置名称输入框占剩余宽度且启用开关固定右侧。完整模拟回归和 x64 Release 打包通过 293 checks。冒烟只切换标签，没有点击网络检查、检测连接、USB 学习、保存、DDC、输入源或唤醒操作。

## 历史任务：W-206 输入源切换与 DDC 调节后端解耦

- 日期：2026-08-31
- 分支：`codex/windows-input-source-transport`
- 基线：`origin/main@0e377256d177cd40ce45fb47b9da300789100dce`，已包含 PR #65 的按需详细诊断实现和界面收尾。
- 实现提交：`19b601181aef40ec2cbef81ae6709c9568b57c25`。
- PR：[#66](https://github.com/maizihk/DisplaySwitch/pull/66)，目标为 `main`，保持 open 等待评审和实机验收。
- 根因：输入源和亮度/对比度/音量虽然业务入口不同，但共同依赖 `IDdcBackend::Write()`，且输入源 VCP 与普通三项混在 `DdcVcpCode`，无法从类型边界证明两条路径互不调用或互不污染。
- 设计：新增独立 `IInputSourceTransport` 与 `InputSourceSwitchService`；`DdcBackendSet` 提供两个独立对象，但共享同一个原生物理显示器会话、句柄集合、解析缓存、topology generation 和全局串行锁。
- 行为保持：USB 离开与协同切屏仍按原显示器映射执行同一 DXVA2 输入源写入，保留一次刷新重试、取消/安全门、离线/歧义零写入、拓扑变化丢弃旧结果和多显示器失败隔离。
- 普通 DDC：`DdcVcpCode` 与 `DdcControlService` 只允许亮度、对比度和音量；旧输入源数值即使被强制构造也会在调用 backend 前拒绝。
- PR #66 评审修复：普通 service 与原生 Read/Write 改为共用同一份三项 VCP 白名单，`0x60` 在显示器解析和 DXVA2 前以 `Unsupported` 拒绝；原生 `Capabilities().known` 保持为 false，不把接口白名单冒充为显示器 MCCS 能力确认。
- generation 评审修复：一次刷新重试以最终结果的 `topologyGeneration` 与 transport 当前 generation 一致为成功条件；受控刷新本身不再被误判，显式 `TopologyChanged` 和外部变化造成的落后结果仍会丢弃并停止剩余显示器。
- 测试边界：DDC fake 与输入源 fake 完全分离；自动测试不访问真实网络、USB、唤醒、DDC 或输入源。
- 本机验证：`Windows/build-windows.ps1` x64 Release 成功，完整原生测试通过 254 项检查；新增受控刷新递增 generation 后重试成功、外部 generation 变化丢弃、service/native 同时拒绝 `0x60` 且 native generation 不变；v2 公共向量为 1 条规范化、4 条认证、20 条消息、6 条状态机，USB-001 至 USB-016 全部通过。
- 产物验证：dist 共 9 个文件、1,828,805 字节，入口与 `runtime/` 完整，低于 20 MiB；扫描未发现配置、诊断日志、个人路径或测试秘密。
- 实机待验：真实 USB 离开和协同切屏、显示器部分失败、句柄刷新重试、热插拔/接口切换后的目标稳定性。
- 范围：只修改 `Windows/` 与本文件；不修改 macOS、协议、contracts、schemaVersion、版本、workflow、tag 或 Release。

## 历史任务：Windows 按需详细诊断记录

- 日期：2026-08-31
- 分支：`codex/windows-detailed-diagnostics`
- 最新主线基线：`origin/main@c7c08f999d4c8d58c37401379e15f60ad34969d9`，通过普通 merge 合入；未 rebase、reset 或丢弃原提交。
- 主线同步 merge 提交：`dbcce044c97315858869d7840523fb2f776da0cd`；冲突仅位于 Windows 清单与本交接文件，解决时同时保留 PR #54/#60 已合并及用户验收、DS-021 发布准备、新增按需详细记录待验收状态和既有实机边界。
- 实现提交：`78d55050a4d775f961b86f5d135cea30ce930c06`
- PR：[#65](https://github.com/maizihk/DisplaySwitch/pull/65) 已合并为 `0e377256d177cd40ce45fb47b9da300789100dce`；按需详细诊断和界面收尾现已进入 main。
- 范围：按需详细诊断记录及其本机设置、测试和 Windows 文档；不修改协议、schemaVersion、版本、workflow、tag 或 Release。

## 已合并基线与发布准备事实

- 主线集成：PR [#54](https://github.com/maizihk/DisplaySwitch/pull/54) 已合并为 `e14ae6ea6d381dd31097406d7d735f41ec9a2699`，PR [#60](https://github.com/maizihk/DisplaySwitch/pull/60) 已合并为 `3a22c66afdb4838040e2fdc5d122ed955337bb13`。
- CI：Windows runs `33366897393`、`33367712427` 均通过构建、自动测试、dist 验证和 artifact 上传。
- 用户验收：最终 Windows 测试包、诊断页和真实局域网协同检测通过，单击检测不再卡死。
- DS-021：PR [#61](https://github.com/maizihk/DisplaySwitch/pull/61) 已完成原生-only、v2-only、六页诊断和绿色测试包的发布准备事实同步。
- 剩余边界：休眠恢复、热插拔、接口切换、高 DPI/辅助功能和清单中明确保留的未覆盖 DDC 场景。

## W-005 / W-203 诊断实现历史

- 日期：2026-08-31
- 功能：W-005 文档与诊断安全、W-203 诊断页面与脱敏日志
- 分支：`codex/windows-w005-w203-diagnostics`
- 集成基线：PR [#54](https://github.com/maizihk/DisplaySwitch/pull/54) 已合并为 `e14ae6ea6d381dd31097406d7d735f41ec9a2699`
- 实现提交：`befd20f49cc11d535bcc3dc8bee0036e1a4550e3`
- PR #60 评审修复提交：`9bfa6d546ae6cc3a9a9284bd01b55b7d55b1582e`，补齐 DDC 批量聚合、心跳诊断生命周期和只读 snapshot provider 边界
- PR：[#60](https://github.com/maizihk/DisplaySwitch/pull/60)，已合并为 `3a22c66afdb4838040e2fdc5d122ed955337bb13`
- CI：合并到 main 后的 Windows runs `33366897393`、`33367712427` 均全绿；本节所列 Windows 本机验证同样通过

## 根因与设计

- 原诊断日志直接接受自由文本，安全性依赖每个调用方自律；现在写盘前统一解析为安全事件名，并只允许预定义的数值字段，未知字段一律删除并标记已脱敏。
- 原显示器最后操作状态只存在于 WinUI `TextBlock`，设置页重建或重新枚举会重置为 idle。现在会话内状态按稳定逻辑显示器 ID、当前不透明物理绑定和 topology generation 关联，不保存句柄：相同绑定重枚举保留状态，绑定或 generation 变化只废弃对应状态，歧义安全拒绝。
- 新增“诊断”标签。报告只投影配置快照、缓存的公开应用元数据和已有内存状态；协同配置、显示器、会话及操作使用 `P1`、`D1`、`S1`、`O1` 临时编号。
- 预览不包含配置名称、地址、配对密码、endpoint、认证/消息标识、用户路径、显示器与 USB 原始身份或友好名称。匿名映射不写配置、不落盘、不跨端同步。
- “刷新预览”不会调用网络检测、USB 枚举/交接、DDC 枚举/读写、唤醒或输入源切换；“复制诊断”仅复制当前可见文本，不刷新也没有第二条导出路径。
- 评审发现 `DisplayOperationTracker::RecordBatch` 曾逐项覆盖同一显示器状态，导致亮度失败后对比度/音量成功可能误报整批成功；现在先按目标显示器聚合，只有全部请求项成功且可信才记录成功，失败、不可信和歧义均安全保留。
- 在线运行态仍按 6 秒窗口从 `v2PeerLastSeenMs_` 失效，但诊断改用独立的会话跟踪器保存最后合法心跳事实，因此会稳定显示 `Never -> Recent -> Expired`；profile/endpoint/地址/端口/认证身份变化、配置删除、安全会话或应用会话重置会清除旧状态，报告不含身份和原始时间。
- 诊断预览正式边界改为 `IDiagnosticSnapshotProvider`：WinUI 预览模型只持有 `ReadSnapshot()`，不能访问 UDP、USB、wake、DDC 或 input-source 接口；刷新调用注入 provider，复制只返回当前可见文本。
- 原详细事件入口无条件写入会话内存和本机 `diagnostic.log`，即使用户没有排障需求也会在启动时创建记录。现在 schema v5 增加可选的本机 `DetailedDiagnosticRecording` 设置，缺失时严格默认为关闭，不修改 schemaVersion。
- “常规”页新增即时保存的“详细诊断记录”。所有 DDC/输入源、USB 与协同网络详细入口最终汇入同一锁内硬门控；关闭时既不保留内存事件也不创建日志文件，任意方向切换都会清空旧内存和旧文件。
- 诊断预览关闭详细记录时仍显示配置、能力、连接和 DDC 基本状态，并明确输出 `detailed-recording=false`；显示器页不再投影后端原始 message，只显示读取/写入成功、失败或匹配歧义。

## 修改范围

- `Windows/DisplaySwitcher.Native/DiagnosticReport.*`：纯诊断快照、严格输出格式、预览模型和显示器操作状态生命周期。
- `Windows/DisplaySwitcher.Native/Diagnostics.*`：日志白名单清洗与有界会话安全事件快照。
- `Windows/DisplaySwitcher.Native/AppConfig.*`、`Controller.cpp`：持久化默认关闭的本机开关，在启动及配置成功应用后同步记录门控。
- `Windows/DisplaySwitcher.Native/Controller.*`、`SystemActions.*`：从现有内存状态投影诊断，并在既有 DDC/输入源完成点记录匿名操作结果。
- `Windows/DisplaySwitcher.Native/SettingsWindow.*`：新增只读诊断页、刷新预览和同文复制；显示器卡片复用会话内最后操作状态。
- `Windows/DisplaySwitcher.Tests/Tests.cpp`：增加默认关闭、旧 v5 缺失字段、持久化、四类入口零记录、开启后记录、双向切换清空、关闭预览不泄漏和简明 DDC 文案测试；保留既有隐私及状态生命周期回归。
- `Windows/README.md`、`Windows/DEVELOPMENT_CHECKLIST.md` 与本交接文件。

## 自动验证

- `Windows/build-windows.ps1` x64 Release 已编译原生应用、绿色版启动器与测试，并真实运行完整 `DisplaySwitcher.Tests.exe`；共通过 246 项检查。
- 合入 `origin/main@c7c08f999d4c8d58c37401379e15f60ad34969d9` 后重新完成同一套验证：仍为 246 项检查全过，dist 共 9 个文件、1,824,709 字节，入口及 `runtime/` 完整，敏感信息扫描无命中。
- 新测试使用临时配置与临时日志路径，证明新安装和缺字段旧配置默认关闭、设置可跨重启回读、关闭时 DDC/输入源/USB/协同网络入口零内存及零文件记录、开启后仅记录后续事件、任意切换清空旧轨迹。
- 关闭状态的诊断投影即使收到人为注入的旧 sessions 也强制显示 0 且不输出事件；注入含 HANDLE、HRESULT、attempt、checksum 与 transport 的 DDC 错误后，用户界面投影仍只有简明“读取失败”。
- W-005/W-203 测试向报告注入私网地址、密码、endpoint、合成 Windows 路径、显示器/USB 标识和设备名称，确认全部不存在，同时保留安全状态和匿名编号。
- 可注入 snapshot provider 测试确认刷新只调用 `ReadSnapshot()`，复制不再次读取且文本逐字一致；该纯投影边界不暴露网络、USB、唤醒、DDC 枚举/读写或输入源接口。
- DDC 批处理测试覆盖亮度失败后对比度/音量成功、不可信估计值和歧义优先级，最终状态分别保持失败/失败/歧义，不再误报 `读取：成功`。
- 模拟时钟覆盖心跳 `Never -> Recent -> Expired`，并验证同一身份重新应用保留 Expired，认证身份/endpoint 变化、配置删除和会话重置安全清除。
- D1、D2、D3 依次成功、相同绑定重枚举、同型号/重排、绑定及 generation 变化和歧义隔离均通过。
- 既有 DS-004、DS-005、DS-007、DS-008、DS-009、DS-012、DS-013 回归通过；v2 公共向量为 1 条规范化、4 条认证、20 条消息、6 条状态机；USB-001 至 USB-016 全部通过。
- dist 绿色版为 framework-dependent，构建脚本报告 1.74 MiB。测试 ZIP 为 `Windows/outputs/DisplaySwitch-Windows-x64-unsigned-framework-dependent-detailed-diagnostics.zip`，850,734 字节，SHA-256 `05490C752161DF8FB7288F34823FE31D551014F38DB8EEA382B01635B69D7DD9`。
- Release 编译启用基于 MSBuild 变量的路径映射；对 dist 扫描确认没有配置/日志、测试秘密、当前 Windows 用户目录或仓库绝对路径。
- NuGet 漏洞索引在受限网络下产生 NU1900 警告；缓存依赖还原、编译、链接、测试和产物检查均成功。

## 实机验收与剩余边界

- PR #69 后续 P1 修复提交待推送：生产 `BuildContent()` 消费 USB/协同布局模型，USB 当前状态元素仍只挂载在独立状态行；保存反馈控制器以 `None`/`Collaboration` 类型范围处理成功、失败、无变化、两秒过期和协同标签页可见性。`CardStrokeColorDefaultBrush`、`SystemFillColorSuccessBrush` 与 `SystemFillColorCriticalBrush` 替换了不合适的主题键。完整模拟回归 291 checks 与 x64 Release dist 打包通过；未执行真实 USB、DDC、输入源、唤醒或网络操作。
- 本机已完成设置窗口、USB 页和协同页实际打开冒烟。浅色/深色/高对比度、100%/150%/200% DPI、窄窗口、长配置名和 0/1/3 台以上显示器仍需专项视觉验收。
- 用户已确认最终测试包的诊断标签、刷新/复制、多显示器状态和真实局域网检测可用，单击检测不再导致程序卡死。
- PR #65 新增“详细诊断记录”开关的即时保存、重启保持、双向切换后的预览内容和旧日志清理仍需实机 GUI 验证。
- 休眠恢复、热插拔、接口切换和常见高 DPI/辅助功能仍需专项实机验证。
- 本轮合并、构建和自动测试不执行新的真实网络、USB、DDC、唤醒、输入源或系统设置操作。

## 范围

- 只修改 `Windows/` 和 `handoffs/windows.md`；未修改 macOS、共享协议/提案/合约、GitHub Actions、版本号、tag 或 Release。
- 实现已通过 PR #54、#60 集成到 `main`；正式安装器、商业签名、tag 和 Release 仍不在本任务范围。
- PR #65 只承载新的按需详细诊断增量；最终 merge SHA、CI 和工作区状态以交付报告为准。

## PR #69 当前物理映射目录修复（2026-09-01）

- 根因：设置窗口曾直接遍历完整 `workingDisplays_`，并在协同页补出历史映射，导致离线、待确认和当前物理显示器一起进入输入源 UI；保存时又从可见编辑器重建映射，单纯隐藏会造成历史映射丢失。
- 修复：生产 `DisplayMappingProjection` 仅在本地物理拓扑可信时更新，并只选择当前最高 topology generation 中 `Resolved`、强绑定且一对一唯一的显示器。RDP、枚举失败和不完整结果保留最后可信投影，不提交目录变化。
- 数据兼容：生产 merge 函数只按可见显示器 ID 更新输入值；历史离线、歧义或待确认目录及 USB/协同映射原样保留，不删除、不重绑定、不覆盖。
- 布局：USB 与协同页共同调用同一个生产映射 Grid；“对端输入源”位于左侧固定标签列，跨实际显示器行并垂直居中，显示器名称使用 Star 列，输入框使用固定宽度列。没有独立整行标题。
- 自动验证：Windows 全量 298 checks 通过。新增模拟场景为 2 台当前物理显示器 + 2 条历史离线目录，验证 UI 仅投影 2 行但 4 条目录和离线映射均保留；覆盖 0、1、3 台以上行跨度以及不可信拓扑保留最后可信投影。
- Release：`Windows/build-windows.ps1 -Architecture x64 -Configuration Release` 成功，绿色包大小 1.77 MiB；仅有既有 NU1900 漏洞索引网络警告。
- UI 冒烟：最终 x64 Release 实际打开 USB 切换和协同页并分别截图。两页均成功构建、无空白或崩溃，共用列宽一致，左侧标签在当前 2 行中垂直居中，历史无名条目未出现。仅切换页面，未点击或执行网络、USB、DDC、输入源、唤醒、学习或保存操作。
- 待实机：0、1、3 台以上实体显示器组合仍待补充验证；自动模型已覆盖。

## PR #69 重复强绑定审核闭环（2026-09-01）

- 根因：单遍 `usedBindings` 只能拒绝后出现的重复项，第一项已进入投影；此外强绑定前缀判断发生在大小写规范化前，会漏掉大小写变体。
- 修复：生产投影先筛选当前可信代次中的 `Resolved`、合法 displayId、规范化后强绑定候选，完整统计小写 displayId 和完整小写 nativeMonitorId 频次；第二遍仅接受两类频次都为 1 的条目。完整绑定字符串保留物理实例后缀，不使用会合并不同实例的 `CanonicalDdcMonitorId`。
- 测试：重复强绑定两项均排除且目录/USB/协同映射不变；重复 displayId 两项均排除；大小写变体按同一绑定排除。既有 2 当前 + 2 历史、UI=2/目录映射=4 和 RDP/Incomplete 保留测试继续通过。全量共 302 checks。
- Release：x64 Release 成功，绿色包 1.78 MiB，仅既有 NU1900 网络警告。
- UI 证据限制：本次最终 Release 只读打开设置窗口和显示器页，本机 4 条目录当前全部为 Offline，因此 USB 映射正确显示 0 行，无法诚实生成审核指定的“两台当前 Resolved”截图。未点击“重新检测显示器”，避免触发目录变化或保存；未执行 USB、DDC、输入源、唤醒、网络或保存操作。待有两台 Resolved 的实机环境补充脱敏截图与 UIA 输出。

- W-034 连续操作补充：托盘滑杆与媒体键在同一锁边界更新投影并入队，覆盖未执行媒体请求也会替换待写值；旧成功/失败仅清理匹配值，过期代次失败不影响新会话。新增覆盖后的 85/90 步进回归。

2026-09-07 发布校验补充：Inno Setup 的 EXE 文件版本默认 0.0.0.0，与 AppVersion 独立；现让 VersionInfoVersion 跟随应用资源，并在打包脚本逐项检查四段版本，失败则拒绝交付。
