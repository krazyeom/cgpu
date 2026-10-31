#!/bin/zsh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "🎨 Ensuring AppIcon and DMG background are ready..."
if [ ! -f AppIcon.icns ]; then
    swift -module-cache-path /tmp/clang-cache generate_icon.swift
    mkdir -p AppIcon.iconset
    sips -z 16 16     AppIcon_1024.png --out AppIcon.iconset/icon_16x16.png
    sips -z 32 32     AppIcon_1024.png --out AppIcon.iconset/icon_16x16@2x.png
    sips -z 32 32     AppIcon_1024.png --out AppIcon.iconset/icon_32x32.png
    sips -z 64 64     AppIcon_1024.png --out AppIcon.iconset/icon_32x32@2x.png
    sips -z 128 128   AppIcon_1024.png --out AppIcon.iconset/icon_128x128.png
    sips -z 256 256   AppIcon_1024.png --out AppIcon.iconset/icon_128x128@2x.png
    sips -z 256 256   AppIcon_1024.png --out AppIcon.iconset/icon_256x256.png
    sips -z 512 512   AppIcon_1024.png --out AppIcon.iconset/icon_256x256@2x.png
    sips -z 512 512   AppIcon_1024.png --out AppIcon.iconset/icon_512x512.png
    sips -z 1024 1024 AppIcon_1024.png --out AppIcon.iconset/icon_512x512@2x.png
    iconutil -c icns AppIcon.iconset -o AppIcon.icns
fi

if [ ! -f dmg_background.png ]; then
    swift -module-cache-path /tmp/clang-cache generate_dmg_background.swift
fi

echo "🔨 Building fresh CGPUMonitor.app..."
./build.sh

VERSION="1.1.0"
DMG_NAME="CGPUMonitor-v${VERSION}.dmg"
VOL_NAME="CGPU Monitor"
TEMP_DMG="dmg_temp.dmg"
STAGING_DIR="dmg_temp"

echo "🧹 Cleaning previous build artifacts..."
rm -rf "$TEMP_DMG" "$DMG_NAME" "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

echo "📂 Staging files for DMG..."
cp -R "CGPUMonitor.app" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
mkdir -p "$STAGING_DIR/.background"
cp dmg_background.png "$STAGING_DIR/.background/background.png"
if [ -f AppIcon.icns ]; then
    cp AppIcon.icns "$STAGING_DIR/.VolumeIcon.icns"
fi

echo "💿 Creating initial read-write DMG..."
hdiutil create -srcfolder "$STAGING_DIR" \
    -volname "$VOL_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size 80m \
    "$TEMP_DMG"

echo "🔌 Mounting temporary DMG..."
MOUNT_DIR="/Volumes/$VOL_NAME"
# 기존 마운트가 있으면 해제
if [ -d "$MOUNT_DIR" ]; then
    hdiutil detach "$MOUNT_DIR" -force 2>/dev/null || true
fi

DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" | grep -E '^/dev/' | head -n 1 | awk '{print $1}')
echo "   Attached as: $DEVICE at $MOUNT_DIR"

sleep 1

echo "🎨 Applying Finder presentation view & layout..."
# AppleScript로 Finder 윈도우 스타일, 배경화면 및 아이콘 위치 지정
osascript <<EOF || true
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {300, 150, 900, 550}
        
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 110
        set background picture of theViewOptions to file ".background:background.png"
        
        set position of item "CGPUMonitor.app" of container window to {150, 205}
        set position of item "Applications" of container window to {450, 205}
        
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

# 볼륨 아이콘 활성화
if [ -f "$MOUNT_DIR/.VolumeIcon.icns" ] && [ -x /usr/bin/SetFile ]; then
    SetFile -a C "$MOUNT_DIR" || true
fi

sleep 1
echo "⏏️ Detaching volume..."
hdiutil detach "$DEVICE" -force || hdiutil detach "$MOUNT_DIR" -force

echo "🗜 Compressing to final DMG..."
hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_NAME"

rm -rf "$TEMP_DMG" "$STAGING_DIR"

echo "✨ Successfully created DMG installer: $DMG_NAME"
ls -lh "$DMG_NAME"
