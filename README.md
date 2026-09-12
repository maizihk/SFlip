# SFlip

[![macOS CI](https://github.com/maizihk/SFlip/actions/workflows/macos.yml/badge.svg)](https://github.com/maizihk/SFlip/actions/workflows/macos.yml)
[![Windows CI](https://github.com/maizihk/SFlip/actions/workflows/windows.yml/badge.svg)](https://github.com/maizihk/SFlip/actions/workflows/windows.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

SFlip 是 macOS 菜单栏和 Windows 托盘工具，适合多台电脑共用显示器。它可以调节外接显示器的亮度、对比度和音量，也能配合 USB 切换器切换显示器输入源。键鼠切换需配合 USB 切换器或 KVM。

## 主要功能

- **显示器调节**：分别调节多台显示器，或开启联动一起调节。
- **USB 自动切换**：设备切走时切换显示器输入源，设备接入时唤醒本机显示器。
- **双机协同**：从菜单中选择目标电脑，唤醒对端显示器并切换输入源。
- **媒体快捷键**：使用键盘亮度、音量和静音键调节外接显示器。

## 下载与安装

当前正式版：Windows **v2.3.2**，macOS **v2.3.0**。各版本的改动见 [发布说明](https://github.com/maizihk/SFlip/releases)。

| 平台 | 系统要求 | 下载 |
| --- | --- | --- |
| macOS | Apple Silicon，macOS 12 或更高版本 | [DMG](https://github.com/maizihk/SFlip/releases/download/v2.3.0/SFlip-v2.3.0-macOS-arm64.dmg) · [ZIP](https://github.com/maizihk/SFlip/releases/download/v2.3.0/SFlip-v2.3.0-macOS-arm64.zip) |
| Windows | x64，Windows 10 1809 或更高版本 | [安装版](https://github.com/maizihk/SFlip/releases/download/v2.3.2/SFlip-v2.3.2-Windows-x64-Setup.exe) · [绿色版 ZIP](https://github.com/maizihk/SFlip/releases/download/v2.3.2/SFlip-v2.3.2-Windows-x64-portable.zip) |

- **macOS**：打开 DMG，把 `SFlip.app` 拖入 `Applications`，再从“应用程序”启动；ZIP 解压后同样放入“应用程序”。
- **Windows 安装版**：运行安装程序，按向导完成安装。若提示缺少运行库，安装后返回重试。
- **Windows 绿色版**：安装 [Windows App Runtime 2.4 x64](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/downloads)，完整解压 ZIP，运行 `SFlip.exe`，保留旁边的 `runtime` 文件夹。

升级前先退出旧版。文件校验值：[Windows](https://github.com/maizihk/SFlip/releases/download/v2.3.2/SHA256SUMS.txt) · [macOS](https://github.com/maizihk/SFlip/releases/download/v2.3.0/SHA256SUMS.txt)。

## 基础使用

下面介绍当前源码的配置方式。配对码自动连接及近期设置改进尚未进入上述正式版，下载版请同时参考对应发布说明。

### 显示器调节

1. 打开“设置”，在“显示器”页检测显示器。
2. 开启需要的亮度、对比度或音量功能，点击“读取 DDC 参数”确认读数。
3. 使用滑杆调节；需要在菜单栏或托盘操作时，开启对应的托盘显示选项。

媒体快捷键可在“常规”中开启。macOS 会申请输入监控权限；可选的 HDMI/DP 音量接管还需要辅助功能权限。

### USB 自动切换

1. 在“USB 切换”页选择或学习会随 USB 切换器切走的设备。
2. 为参与切换的显示器填写目标输入源编号，不参与的留空。
3. 开启 USB 自动切换。设备离开时切换输入源，接入时唤醒本机显示器。

输入源编号的获取方法见 [输入源教程](docs/INPUT_SOURCES.md)。首次测试前，先确认能通过显示器实体按键切回原输入源。

### 双机协同

1. 两台电脑都运行 SFlip，并连接到同一可信局域网。
2. 在各自“协同”页填写配置名称、另一台电脑的地址、相同端口和相同配对码。默认端口是 `49731`，配对码建议使用 8–128 位字母或数字。
3. 填写参与切换的显示器输入源编号，然后开启配置。字段完整即可开启，对端离线也能保存。
4. 点击“检测连接”查看结果；连接成功后，从菜单栏或托盘选择“切换到 配置名称”。

USB 自动切换可独立使用，如需同时唤醒对端，在 USB 页开启联动并选择协同配置。

## 兼容性与问题反馈

显示器需要支持并开启 DDC/CI，线材、转接器、扩展坞或 KVM 也需要支持透传。部分显示器只支持亮度等部分参数，HDMI/DP 音量调节还取决于显示器能力。

macOS 当前支持 Apple Silicon；Windows 需要 Windows App Runtime 2.4 x64。更多设备情况见 [硬件兼容性](COMPATIBILITY.md)。

遇到问题可先查看 [支持说明](SUPPORT.md)，再提交兼容性报告或 [Issue](https://github.com/maizihk/SFlip/issues)。安全问题请按 [安全策略](SECURITY.md) 联系维护者。

## 源码构建

获取源码后，在仓库根目录执行：

- **macOS**：需要完整 Xcode 27 和 Python 3，运行 `./macOS/scripts/build-app.sh`。
- **Windows**：需要 Visual Studio 2026 的 C++ 桌面开发与 Windows App SDK 组件，运行 `.\Windows\build-windows.ps1`。

Windows 安装包构建和详细依赖见 [Windows README](Windows/README.md)；参与开发见 [贡献指南](CONTRIBUTING.md)。

## 许可证

SFlip 使用 [MIT License](LICENSE)。macOS DDC 后端基于 [AppleSiliconDDC](https://github.com/waydabber/AppleSiliconDDC)，第三方声明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
