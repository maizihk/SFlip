#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <DisplaySwitcher.app> <output.dmg>" >&2
    exit 2
fi
APP_PATH="$1"
DMG_PATH="$2"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="$PROJECT_DIR/.build/dmg-tools"
[[ -d "$APP_PATH" && "$DMG_PATH" == *.dmg ]]
/usr/bin/codesign --verify --deep --strict "$APP_PATH"
# Keep packaging dependencies isolated from the system Python. Pin transitive versions too.
if [[ ! -x "$TOOLS_DIR/bin/python3" ]]; then
    python3 -m venv "$TOOLS_DIR"
fi
"$TOOLS_DIR/bin/python3" -m pip install --disable-pip-version-check \
    -r "$PROJECT_DIR/scripts/dmg/requirements.txt"
/bin/mkdir -p "$(/usr/bin/dirname "$DMG_PATH")"
WORK_DIR="$(/usr/bin/mktemp -d /private/tmp/DisplaySwitcher-dmg.XXXXXX)"
CONTENTS="$WORK_DIR/contents"
MOUNT_POINT="$WORK_DIR/mount"
MOUNTED=false
cleanup() {
    local status=$?
    if [[ "$MOUNTED" == true ]]; then
        if ! /usr/bin/hdiutil detach "$MOUNT_POINT" >/dev/null; then
            echo "Cannot detach DMG verification volume: $MOUNT_POINT" >&2
            return 1
        fi
    fi
    /bin/rm -rf "$WORK_DIR"
    return "$status"
}
trap cleanup EXIT
/bin/mkdir -p "$CONTENTS" "$MOUNT_POINT"
/usr/bin/ditto --norsrc "$APP_PATH" "$CONTENTS/DisplaySwitcher.app"
/bin/ln -s /Applications "$CONTENTS/Applications"
cat > "$CONTENTS/安装说明.txt" <<'INSTRUCTIONS'
安装 DisplaySwitch

1. 将 DisplaySwitcher.app 拖到旁边的 Applications（应用程序）文件夹。
2. 如果替换旧版，请先退出正在运行的 DisplaySwitch，再确认替换。
3. 复制完成后推出此磁盘映像，从“应用程序”打开 DisplaySwitcher。
4. 在设置中按需要配置显示器、USB 与协同，并申请所需权限。

请勿直接从磁盘映像运行应用。
这是未经公证的测试包。DMG 不会自动安装、申请权限或改变系统设置。
INSTRUCTIONS
/usr/bin/xcrun swift "$PROJECT_DIR/scripts/dmg/render-background.swift" "$WORK_DIR/background.tiff"
"$TOOLS_DIR/bin/dmgbuild" -s "$PROJECT_DIR/scripts/dmg/settings.py" \
    -D "contents=$CONTENTS" -D "background=$WORK_DIR/background.tiff" \
    -D "icon=$PROJECT_DIR/Resources/AppIcon.icns" \
    DisplaySwitch "$WORK_DIR/DisplaySwitcher.dmg"
/usr/bin/hdiutil verify "$WORK_DIR/DisplaySwitcher.dmg" >/dev/null
/usr/bin/hdiutil attach "$WORK_DIR/DisplaySwitcher.dmg" -readonly -nobrowse \
    -noautoopen -mountpoint "$MOUNT_POINT" >/dev/null
MOUNTED=true
[[ -d "$MOUNT_POINT/DisplaySwitcher.app" ]]
[[ -L "$MOUNT_POINT/Applications" ]]
[[ "$(/usr/bin/readlink "$MOUNT_POINT/Applications")" == /Applications ]]
[[ -f "$MOUNT_POINT/安装说明.txt" ]]
[[ -f "$MOUNT_POINT/.DS_Store" ]]
/usr/bin/codesign --verify --deep --strict "$MOUNT_POINT/DisplaySwitcher.app"
# Verify the copy that Finder will install, without touching /Applications.
/usr/bin/ditto --norsrc "$MOUNT_POINT/DisplaySwitcher.app" "$WORK_DIR/installed/DisplaySwitcher.app"
/usr/bin/codesign --verify --deep --strict "$WORK_DIR/installed/DisplaySwitcher.app"
/usr/bin/hdiutil detach "$MOUNT_POINT" >/dev/null
MOUNTED=false
/bin/mv -f "$WORK_DIR/DisplaySwitcher.dmg" "$DMG_PATH"
echo "$DMG_PATH"
