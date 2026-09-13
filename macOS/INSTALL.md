# 在 Mac 上安装 SFlip

当前版本未经过 Apple 公证，首次启动可能需要手动允许。

1. 用 Safari 打开 [GitHub Release](https://github.com/maizihk/SFlip/releases/latest)，下载 macOS arm64 的 DMG。
2. 退出旧版 SFlip，打开 DMG，将 SFlip.app 拖入 Applications。复制完成后推出 DMG。
3. 从“应用程序”打开 SFlip。
4. 如果 macOS 提示无法验证开发者或无法检查软件，进入“系统设置 → 隐私与安全性”，找到 SFlip，点击“仍要打开”，再确认“打开”。

ZIP 版本解压后同样先移入“应用程序”，再按上述步骤打开。

如果只显示“应用程序无法打开”，没有“仍要打开”，或允许后仍失败，请先用 Safari 从 GitHub 重新下载一份，避免继续使用经内置浏览器、聊天附件或其他工具转存的副本。有些下载工具会给文件加上额外的执行限制，普通手动放行不一定能解除；这和缺少公证不是同一件事。

重新下载后仍失败，请反馈 macOS 版本、下载工具和完整提示。安装过程无需终端命令。

参考：[苹果的手动打开说明](https://support.apple.com/zh-cn/102445) · [下载工具导致执行限制的案例](https://developer.apple.com/forums/thread/767612)

# Installing SFlip on macOS

The current release is not notarized by Apple, so the first launch may require manual approval.

1. Download the macOS arm64 DMG directly from [GitHub Releases](https://github.com/maizihk/SFlip/releases/latest) using Safari.
2. Quit the previous version, drag SFlip.app into Applications, then eject the DMG.
3. Open SFlip from Applications.
4. If macOS cannot verify the developer or check the app, go to System Settings → Privacy & Security, choose Open Anyway for SFlip, then confirm Open.

For the ZIP version, extract the app and move it to Applications first.

If the message only says the application cannot be opened, Open Anyway is missing, or approval does not help, download a fresh copy directly using Safari. Embedded browsers, attachment downloads, or transfer tools may add a separate execution restriction; this is different from a missing notarization ticket.

If the fresh download still fails, report the macOS version, download tool, and exact message. No Terminal commands are required for this installation procedure.
