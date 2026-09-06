# DisplaySwitch

[![macOS CI](https://github.com/maizihk/DisplaySwitch/actions/workflows/macos.yml/badge.svg)](https://github.com/maizihk/DisplaySwitch/actions/workflows/macos.yml)
[![Windows CI](https://github.com/maizihk/DisplaySwitch/actions/workflows/windows.yml/badge.svg)](https://github.com/maizihk/DisplaySwitch/actions/workflows/windows.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

DisplaySwitch 是一个原生 macOS 菜单栏 / Windows 托盘工具，用于多台电脑共用显示器的场景。它通过 DDC/CI 调节亮度、对比度和音量，并在 USB 设备离开或用户手动选择目标时切换显示器输入源。

**键盘和鼠标的物理转接仍需 USB 切换器或 KVM 等硬件。** DisplaySwitch 监听本机 USB 设备的接入与离开，再控制显示器；它不传输键鼠输入，也不代替 USB 切换器。

## 下载与安装

[查看最新发布](https://github.com/maizihk/DisplaySwitch/releases/latest) · [硬件兼容性](COMPATIBILITY.md)

当前发布为 **v2.2.0（build 20）测试包**。macOS 使用 ad-hoc 签名且未经公证；Windows 包未签名。

> **发布包与主线的区别**：`main` 已合入 [#82](https://github.com/maizihk/DisplaySwitch/pull/82) 的协同和连续调节修复，现有 v2.2.0 下载包尚未包含这些修复。需要这些修复时，请按下方“源码构建”说明构建当前主线；发布包所含变更以对应 Release 说明为准。

| 平台 | 运行要求 | v2.2.0 下载 |
| --- | --- | --- |
| macOS | Apple Silicon，macOS 12 或更高版本 | [macOS arm64 ZIP](https://github.com/maizihk/DisplaySwitch/releases/download/v2.2.0/DisplaySwitcher-v2.2.0-macOS-arm64-unsigned.zip) |
| Windows | x64，Windows 10 1809 或更高版本；Windows App Runtime 2.4 x64 | [Windows x64 ZIP](https://github.com/maizihk/DisplaySwitch/releases/download/v2.2.0/DisplaySwitcher-v2.2.0-Windows-x64-unsigned-framework-dependent.zip) |

文件校验值见 [SHA256SUMS.txt](https://github.com/maizihk/DisplaySwitch/releases/download/v2.2.0/SHA256SUMS.txt)。Intel Mac 当前不支持原生 DDC；Windows 版不依赖 .NET。

- **macOS**：解压后将 `DisplaySwitcher.app` 放到固定的 `/Applications` 目录，再启动应用。
- **Windows**：先安装 Microsoft Windows App Runtime 2.4 x64（[微软下载页](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/downloads)），再将 ZIP 完整解压到固定目录，运行顶层 `DisplaySwitch.exe`。必须保留旁边的 `runtime` 子目录，不能只复制一个 EXE。

运行前还需确认：显示器已启用 DDC/CI，当前接口、线材、转接器、扩展坞或 KVM 能透传 DDC/CI。支持情况取决于完整连接链路，详见 [兼容性说明](COMPATIBILITY.md)。

## 首次配置

新安装默认关闭 USB 自动切换、协同和各项 DDC 控制，请按需要逐项配置。

### 1. 显示器调节

1. 从菜单栏或托盘打开“设置…”，检测显示器并确认数量、名称和连接状态。
2. 开启需要使用的亮度、对比度或音量功能，再点击“读取 DDC 参数”确认能否读取。关闭的项目不会读取或写入。
3. 读数确认后再使用滑杆或媒体键调节；需要在菜单栏或托盘显示的项目，还需开启对应托盘开关。

### 2. USB 自动切换（可选）

1. 在“USB 切换”页选择或学习一个会随 USB 切换器切走的 Hub、键盘等设备。
2. 为参与切换的显示器填写“USB 离开后切到的输入源”。请自行确认输入源编号；不参与切换的显示器留空，不要填写 `0`。
3. 确认设备和映射后开启 USB 自动切换。设备离开时切换显示器输入源，接入时只唤醒本机显示器。
4. 如需同时唤醒另一台电脑的显示器，先完成下方协同配置，再开启联动并明确选择该配置。

USB 本机切换无需网络，也不等待对端回复。输入源切换可能立即导致黑屏，首次测试前应保留显示器实体按键等恢复输入源的方法。

### 3. 双机协同（可选）

1. 在两台电脑上运行应用，确保双方位于可信局域网。
2. 在各自“协同”页填写配置名称、**另一台电脑**的地址、相同 UDP 端口和相同配对码。默认端口为 `49731`；配对码经 NFC 规范化后须为 8 至 128 个 UTF-8 字节。
3. 为需要切换的显示器填写对端输入源；不参与切换的显示器留空。
4. 两端分别点击“检测”，检测成功后确认对端身份。检测本身不会切屏、唤醒或自动开启配置。
5. 确认并保存身份与映射后开启配置，从菜单栏或托盘选择“切换到 {配置名称}”。

已绑定的对端身份发生变化时，需要重新检测并由用户确认。更完整的协议定义见 [PROTOCOL.md](PROTOCOL.md)。

## 功能与限制

### 显示器与媒体键

- **多显示器调节**：支持亮度、对比度和音量，可分别调节或显式开启联动。只有启用对应功能且符合操作条件的显示器参与。
- **媒体键**：识别键盘实际发出的亮度、音量增减和静音动作，不猜测 Fn 或厂商自定义键码。Windows 亮度键需要设备提供标准 HID Consumer Control 事件。
- **macOS 输入监控权限**：用于媒体键关联；未授权时该功能停用，普通显示器控制仍可使用。
- **macOS HDMI/DP 音量接管**：可选且默认关闭，需要辅助功能权限。仅在默认音频输出为 HDMI/DisplayPort、系统无法调节其音量且 DDC 控制条件满足时接管音量媒体键。普通监听模式保留系统原生行为；Windows 版也不吞键。
- **显示器管理**：保留暂时离线的配置；在可信检测后由用户手动删除，不按显示器名称或枚举顺序猜测目标。

### 协同与输入源切换

USB 切换与手动协同是独立路径。USB 离开时立即执行本机输入源切换，可选通知一个明确目标唤醒；网络失败不会阻断或回滚本机操作。

当前 `main` 的手动协同先请求目标唤醒，再在收到确认后切屏；最近在线的目标在 600 ms 内未确认时允许对该目标降级切换，离线目标则提示不可用并取消。只联系用户选择的目标，不广播、不自动选择其他配置。现有 v2.2.0 包的差异见上方发布说明。

### 兼容性与隐私

- macOS 使用 CoreDisplay / IOAVService 原生 DDC，Windows 使用 Dxva2；原生控制失败时明确报错，不回退到外部工具或软件调光。
- macOS 使用 Apple 私有显示接口，系统大版本更新后需重新验证。Windows 远程桌面、虚拟/镜像目标或不完整拓扑不能作为可信物理显示器执行 DDC。
- 显示器可能只支持部分 DDC 控制项；单项失败不代表整条连接链路不可用。自动测试不能替代实机兼容性验证。
- 协议 v2 使用 PBKDF2-HMAC-SHA256 认证，并校验消息方向、时间窗和重放；通信内容不加密，应仅在可信局域网使用。
- USB 标识、显示器身份、地址和配对码等配置保留在本机，不作为跨端同步数据。详细诊断默认关闭，开启后记录脱敏信息。

遇到问题请使用 [兼容性报告模板](COMPATIBILITY.md#anonymized-compatibility-report-template) 并删除个人信息；安全漏洞按 [安全策略](SECURITY.md) 私下报告。

## 源码构建

以下是当前主线的构建要求，与上面的应用运行要求不同。先获取源码并进入仓库根目录：

```bash
git clone https://github.com/maizihk/DisplaySwitch.git
cd DisplaySwitch
```

### macOS

正式实现为 Swift / AppKit。当前源码使用 macOS 27 SDK API，需使用包含该 SDK 的完整 **Xcode 27**；仅安装 Command Line Tools 不够。CI 使用 `xcode-27` 环境。

```bash
xcode-select -p
xcodebuild -version
xcrun --sdk macosx --show-sdk-version
./macOS/scripts/build-app.sh
```

如果使用 Xcode beta，可通过本次命令的 `DEVELOPER_DIR` 指定工具链，例如：

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./macOS/scripts/build-app.sh
```

输出为 `macOS/outputs/DisplaySwitcher.app` 和 `macOS/outputs/DisplaySwitcher-macOS-<arch>.zip`。脚本默认使用 ad-hoc 签名；如需稳定保留本机权限记录，可指定钥匙串中的 Apple Development 身份：

```bash
DISPLAYSWITCH_CODESIGN_IDENTITY="<identity SHA-1 or exact name>" \
  ./macOS/scripts/build-app.sh
```

Apple Development 签名用于本机测试，不等同于 Developer ID 或公证。

### Windows

正式实现为 C++ / WinUI 3。当前工程要求 **Visual Studio 2026（18.x）**、C++ 桌面开发与 Windows App SDK C++ 组件、**MSVC v145** 和 **Windows SDK 10.0.26100.0**；CI 使用 `windows-2025-vs2026` 环境。

在仓库根目录的 PowerShell 中执行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Windows\build-windows.ps1
```

脚本构建 x64 Release、运行原生自动测试并生成 `Windows\dist\DisplaySwitch.exe` 和 `Windows\dist\runtime\...`。分发时保留完整 `dist` 目录。详细说明见 [Windows README](Windows/README.md)。

正式源码位于 `macOS/` 和 `Windows/DisplaySwitcher.Native/`；`Windows/DisplaySwitcher.Launcher/` 是绿色版启动器。`Windows/DisplaySwitcher.Windows/` 仅为旧 C# 迁移参照，不参与正式构建。

## 文档

| 文档 | 内容 |
| --- | --- |
| [COMPATIBILITY.md](COMPATIBILITY.md) | 硬件兼容性与验证方法 |
| [Windows/README.md](Windows/README.md) | Windows 安装、配置与测试 |
| [PROTOCOL.md](PROTOCOL.md) | 双端通信规范 |
| [contracts/protocol-v2](contracts/protocol-v2/) | 协议 schema 与跨端测试向量 |
| [contracts/usb-switch-v1](contracts/usb-switch-v1/) | USB 状态机公共测试合同 |
| [SUPPORT.md](SUPPORT.md) | 获取支持与提交问题 |
| [CONTRIBUTING.md](CONTRIBUTING.md) | 开发与贡献流程 |

## License

DisplaySwitch 使用 [MIT License](LICENSE)。macOS DDC 后端基于 MIT 许可的 [AppleSiliconDDC](https://github.com/waydabber/AppleSiliconDDC)，完整第三方声明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
