#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="CPA Codex Manager"
DIST_DIR="$PROJECT_ROOT/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
DMG_RW_PATH="$DIST_DIR/$APP_NAME-rw.dmg"
DMG_STAGING="$DIST_DIR/.dmg-staging"
ICON_ICNS="$PROJECT_ROOT/assets/icon.icns"
ICONSET_SOURCE_DIR="$PROJECT_ROOT/assets/macOS/AppIcon.iconset"
GENERATED_ICONSET_DIR="$PROJECT_ROOT/assets/macOS/AppIcon.generated.iconset"
MACOS_ICON_ICNS="$PROJECT_ROOT/assets/macOS/AppIcon.icns"
ICON_SOURCE_JPG="$PROJECT_ROOT/assets/icon.jpg"
ICON_SOURCE_PNG="$PROJECT_ROOT/assets/icon.png"
ICON_FALLBACK_PNG="$ICONSET_SOURCE_DIR/icon_512x512@2x.png"
ICON_FALLBACK_PNG_SMALL="$ICONSET_SOURCE_DIR/icon_512x512.png"
ICON_SOURCE_CONVERTED_PNG="$PROJECT_ROOT/assets/.icon.build.png"
ICON_SOURCE_PADDED_PNG="$PROJECT_ROOT/assets/.icon.padded.png"
ICONSET_DIR="$PROJECT_ROOT/assets/icon.iconset"
BACKGROUND_DIR="$PROJECT_ROOT/assets/dmg"
BACKGROUND_PNG="$BACKGROUND_DIR/background.png"
VOLUME_NAME="$APP_NAME"
WINDOW_BOUNDS="{120, 120, 900, 560}"
APP_ICON_POS="{300, 300}"
APPLICATIONS_POS="{600, 300}"
APP_ICON_SIZE=140
MOUNT_POINT="/Volumes/$VOLUME_NAME"
ICON_CANVAS_SIZE=1024
ICON_CONTENT_SIZE=820

cleanup() {
  rm -rf "$ICONSET_DIR" "$GENERATED_ICONSET_DIR" "$ICON_SOURCE_CONVERTED_PNG" "$ICON_SOURCE_PADDED_PNG" "$DMG_STAGING"
  if mount | grep -q "on $MOUNT_POINT "; then
    hdiutil detach "$MOUNT_POINT" -quiet || true
  fi
}

trap cleanup EXIT

generate_icns() {
  local source_png=""
  local source_image=""

  if [[ -f "$ICON_SOURCE_JPG" ]]; then
    source_image="$ICON_SOURCE_JPG"
  elif [[ -f "$ICON_SOURCE_PNG" ]]; then
    source_image="$ICON_SOURCE_PNG"
  elif [[ -f "$ICON_FALLBACK_PNG" ]]; then
    source_image="$ICON_FALLBACK_PNG"
  elif [[ -f "$ICON_FALLBACK_PNG_SMALL" ]]; then
    source_image="$ICON_FALLBACK_PNG_SMALL"
  fi

  if [[ -n "$source_image" ]]; then
    echo "生成 macOS 风格图标底板: $source_image"
    if [[ "$source_image" == *.jpg || "$source_image" == *.jpeg || "$source_image" == *.JPG || "$source_image" == *.JPEG ]]; then
      sips -s format png "$source_image" --out "$ICON_SOURCE_CONVERTED_PNG" >/dev/null
      source_png="$ICON_SOURCE_CONVERTED_PNG"
    else
      source_png="$source_image"
    fi

    xcrun swift "$PROJECT_ROOT/scripts/generate_macos_icon.swift" "$source_png" "$GENERATED_ICONSET_DIR" >/dev/null
    iconutil -c icns "$GENERATED_ICONSET_DIR" -o "$MACOS_ICON_ICNS"
    cp "$MACOS_ICON_ICNS" "$ICON_ICNS"
    echo "已生成 macOS 风格图标: $MACOS_ICON_ICNS"
    return 0
  fi

  if [[ -f "$ICON_ICNS" ]]; then
    echo "复用现有 macOS 图标: $ICON_ICNS"
    return 0
  fi

  if [[ -f "$ICON_SOURCE_JPG" ]]; then
    sips -s format png "$ICON_SOURCE_JPG" --out "$ICON_SOURCE_CONVERTED_PNG" >/dev/null
    source_png="$ICON_SOURCE_CONVERTED_PNG"
  elif [[ -f "$ICON_SOURCE_PNG" ]]; then
    source_png="$ICON_SOURCE_PNG"
  else
    echo "未找到 $ICON_SOURCE_JPG 或 $ICON_SOURCE_PNG，无法自动生成 .icns"
    return 1
  fi

  echo "自动从图标源文件生成 assets/icon.icns"
  sips -Z "$ICON_CONTENT_SIZE" "$source_png" --out "$ICON_SOURCE_PADDED_PNG" >/dev/null
  sips -p "$ICON_CANVAS_SIZE" "$ICON_CANVAS_SIZE" "$ICON_SOURCE_PADDED_PNG" --out "$ICON_SOURCE_PADDED_PNG" >/dev/null

  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"

  sips -z 16 16     "$ICON_SOURCE_PADDED_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32     "$ICON_SOURCE_PADDED_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32     "$ICON_SOURCE_PADDED_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64     "$ICON_SOURCE_PADDED_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128   "$ICON_SOURCE_PADDED_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256   "$ICON_SOURCE_PADDED_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256   "$ICON_SOURCE_PADDED_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512   "$ICON_SOURCE_PADDED_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512   "$ICON_SOURCE_PADDED_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  cp "$ICON_SOURCE_PADDED_PNG" "$ICONSET_DIR/icon_512x512@2x.png"

  iconutil -c icns "$ICONSET_DIR" -o "$ICON_ICNS"
  echo "已生成: $ICON_ICNS（内容缩放为 ${ICON_CONTENT_SIZE}px，避免 Dock 中显得偏大）"
}

prepare_dmg_background() {
  mkdir -p "$BACKGROUND_DIR"
  if [[ -f "$BACKGROUND_PNG" ]]; then
    return 0
  fi

  python3 <<'PY'
from pathlib import Path
import base64

data = b'iVBORw0KGgoAAAANSUhEUgAAA4QAAAIYCAIAAACD6UEJAAAHB0lEQVR4nO3WQQ0AIBDAsAP/nuGNAvZoFSzZmj0AAODv2w4AAICxDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCRDAAAwJEMAADAkQwAAMCZDxFmBv0R0WcKAAAAAElFTkSuQmCC'
Path('assets/dmg/background.png').write_bytes(base64.b64decode(data))
PY
}

customize_dmg_layout() {
  local device

  rm -f "$DMG_RW_PATH"
  hdiutil create -srcfolder "$DMG_STAGING" -volname "$VOLUME_NAME" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW "$DMG_RW_PATH" >/dev/null

  device=$(hdiutil attach -readwrite -readwrite -noverify -noautoopen "$DMG_RW_PATH" | awk '/Apple_HFS/ {print $1; exit}')
  if [[ -z "$device" ]]; then
    echo "挂载 DMG 失败"
    return 1
  fi

  osascript <<EOF
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to $WINDOW_BOUNDS
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to $APP_ICON_SIZE
    set text size of viewOptions to 14
    set background picture of viewOptions to file ".background:background.png"
    set position of item "$APP_NAME.app" of container window to $APP_ICON_POS
    set position of item "Applications" of container window to $APPLICATIONS_POS
    close
    open
    update without registering applications
    delay 2
  end tell
end tell
EOF

  bless --folder "$MOUNT_POINT" --openfolder "$MOUNT_POINT" >/dev/null 2>&1 || true
  sync
  hdiutil detach "$device" -quiet
  hdiutil convert "$DMG_RW_PATH" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
  rm -f "$DMG_RW_PATH"
}

echo "[1/4] 清理旧产物"
rm -rf "$PROJECT_ROOT/build" "$DIST_DIR/$APP_NAME" "$APP_PATH" "$DMG_PATH" "$DMG_RW_PATH" "$DMG_STAGING"

echo "[2/4] 检查依赖"
python3 -m PyInstaller --version >/dev/null
python3 -c "import webview" >/dev/null
generate_icns || true
prepare_dmg_background

if [[ -f "$ICON_ICNS" ]]; then
  echo "检测到 macOS 图标: $ICON_ICNS"
else
  echo "未检测到 assets/icon.icns，当前将使用默认应用图标"
fi

echo "[3/4] 构建 macOS App"
cd "$PROJECT_ROOT"
python3 -m PyInstaller --noconfirm --clean "$PROJECT_ROOT/CPA-Codex-Manager-Desktop.spec"

if [[ ! -d "$APP_PATH" ]]; then
  echo "未找到 app 产物: $APP_PATH"
  exit 1
fi

echo "[4/4] 生成 DMG"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
mkdir -p "$DMG_STAGING/.background"
cp "$BACKGROUND_PNG" "$DMG_STAGING/.background/background.png"
customize_dmg_layout

echo "构建完成"
echo "APP: $APP_PATH"
echo "DMG: $DMG_PATH"