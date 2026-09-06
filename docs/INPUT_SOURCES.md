# 首次使用：获取显示器输入源编号

[返回 README](../README.md#首次配置)

DisplaySwitch 的“对端输入源”和“USB 离开后切到的输入源”，填写的是**目标显示器接口的 DDC 输入源值（十进制）**。它不是 Windows 的“显示器 1/2”、macOS 显示器排列序号，也不是 USB 设备 ID。

当前应用的“读取 DDC 参数”只读取亮度、对比度和音量，不能自动获取输入源编号。下面的工具仅用于用户手动查询，DisplaySwitch 不会调用它们，也不需要它们常驻。

## 1. 先记清楚线接在哪个接口

查看显示器背部接口标记和显示器自身菜单（OSD），记录每台电脑接入的接口。以同一台显示器为例：

| 电脑 | 显示器上的接口 | 当前读到的输入源值 |
| --- | --- | --- |
| Mac | 实际接口名称，例如 DP | 稍后读取 |
| Windows | 实际接口名称，例如 HDMI 1 | 稍后读取 |

先保持 DisplaySwitch 的 USB 自动切换和协同关闭。查询前退出正在自动控制显示器的工具，确认可以用显示器实体按键恢复输入源。后文的查询命令只读取状态；用 OSD 手动换接口会改变画面。

**每次先用 OSD 切到要记录的接口，让该接口对应的电脑显示画面，再在那台电脑上读取。** 不要把当前 DP 接口读到的值，记成尚未切过去的 HDMI 值；切换后如果原电脑失去显示器连接，也不要继续拿原电脑的缓存当读数。

## 2. Windows：用 ControlMyMonitor 查看当前值

1. 从 [NirSoft 官方页面](https://www.nirsoft.net/utils/control_my_monitor.html) 下载并解压 ControlMyMonitor，运行程序。
2. 在顶部显示器列表中选择目标屏。多屏时核对名称及本机标识，不能默认第一项就是要配置的屏。
3. 找到 **VCP Code 为 `60`、名称为 `Input Select`** 的行，记录 **Current Value** 列。`60` 是十六进制功能代码 `0x60`，要填写的是这一行的当前值，不是 `60`。
4. 记录后退出工具。若手动换了接口，再在当前有画面的电脑上重新读取；必要时重新打开工具刷新列表。

这一步无需双击修改数值，也无需运行 `/SetValue`。该获取方法见 [NirSoft 输入源说明](https://www.nirsoft.net/articles/set_monitor_input_source_command_line.html)。

## 3. macOS Apple Silicon：用 m1ddc 查询

如果已安装 Homebrew，可用以下命令安装查询工具：

```bash
brew install m1ddc
```

安装来源见 [Homebrew m1ddc 页面](https://formulae.brew.sh/formula/m1ddc)；没有 Homebrew 时也可按 [m1ddc 上游说明](https://github.com/waydabber/m1ddc) 从源码构建。该工具不支持 Intel Mac，不保证每种显示器和连接链路都能读取。

先列出当前显示器：

```bash
m1ddc display list detailed
```

核对目标屏，将下面引号里的文字替换成列表中的目标 UUID，再运行：

```bash
input_display_selector='替换为目标显示器的UUID'
m1ddc display "$input_display_selector" get input
```

正常返回的数字是当前输入源值，例如返回 `15`，就记录十进制 `15`。UUID 只用于选择要查询的屏，不能填入 DisplaySwitch 的输入源框。热插拔或换接口后重新枚举；列表序号不等于系统排列序号。

`get input` 的解析与十进制输出可在 [m1ddc 源码](https://github.com/waydabber/m1ddc/blob/main/sources/m1ddc.m) 中核对。若报错、返回 `0`，或读数与 OSD 切换不对应，先按下文排查，不把结果当成已确认映射。

## 4. 常见编号只能用来核对

以下是 MCCS 常见定义，**不是所有显示器都使用这些值**：

| 接口 | 工具可能显示的十六进制 | DisplaySwitch 中填写的十进制 |
| --- | --- | --- |
| DisplayPort 1 | `0x0F` | `15` |
| DisplayPort 2 | `0x10` | `16` |
| HDMI 1 | `0x11` | `17` |
| HDMI 2 | `0x12` | `18` |

例如 `0x11` 应填 **17**，不能填 `11` 或 `0x11`。没有十六进制标记时，先确认工具的显示格式再换算。

USB-C 没有通用的输入源值，不能一律填 `27`；即便工具列出“支持的值”，显示器上报也可能不准确。应以当前接口的实际读取、厂商对该型号的 DDC 说明及最终切换结果为准。上述标准值和厂商差异见 [ddcutil FAQ](https://www.ddcutil.com/faq/)。

## 5. 填的是“要切去的接口”

假设你已经实测确认：这台屏的 Mac 接口值为 `15`，Windows 接口值为 `17`，那么：

| 在哪里配置 | 要切去哪台电脑 | 填入这台屏的值 |
| --- | --- | --- |
| Mac 的 Windows 协同配置 | Windows | `17` |
| Windows 的 Mac 协同配置 | Mac | `15` |
| Mac 的 USB 离开映射，目标为 Windows | Windows | `17` |
| Windows 的 USB 离开映射，目标为 Mac | Mac | `15` |

以上仅为示例，不要直接套到自己的显示器。多屏需逐台记录，不能因接口名称相同就复制一个数值。有效输入为 `1–65535` 的十进制整数，不参与切换的屏留空，不能填 `0`。

## 6. 读取失败与首次验证

- **找不到 `Input Select`、报错或读到 `0`**：检查显示器的 DDC/CI 开关和当前接口连接；可换到另一台已连接电脑查询，或查厂商针对该型号的 DDC/MCCS 文档。读不到不等于不能写，但也不能因此猜值。
- **工具能调亮度，却不能读输入源**：不同 VCP 项的支持情况可以不同。显示器序列号、EDID 或操作系统屏幕编号不能替代输入源值。
- **只有厂商专用 `input-alt` 才有效**：它使用另一条 VCP 通道，不能把读出的专用值直接当作普通 `input` 值填写。DisplaySwitch 当前输入源路径使用标准 `0x60`，不会自动改用该通道。
- **编号确认后**：先退出查询工具，让目标电脑保持有画面可用的输出，保留 OSD 恢复方法，再从 DisplaySwitch 手动验证一个明确目标。观察实际画面是否切到正确电脑；不能只凭“写入成功”判断。
- **首次验证失败**：用 OSD 恢复原接口，保持自动切换关闭，再检查映射和链路。不要循环尝试所有编号。确认两端方向都正确后再开启日常 USB 自动切换。

准备提交问题时使用 [兼容性报告模板](../COMPATIBILITY.md#anonymized-compatibility-report-template)，删除 UUID、序列号等本机标识。
