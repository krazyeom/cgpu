#!/bin/zsh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "🔨 Building CGPUMonitor..."
mkdir -p /tmp/clang-cache

swiftc -parse-as-library \
    -module-cache-path /tmp/clang-cache \
    Sources/CGPUMonitor/AppConfig.swift \
    Sources/CGPUMonitor/Localization.swift \
    Sources/CGPUMonitor/SystemMetrics.swift \
    Sources/CGPUMonitor/DetailPopovers.swift \
    Sources/CGPUMonitor/WidgetView.swift \
    Sources/CGPUMonitor/main.swift \
    -framework AppKit \
    -framework SwiftUI \
    -framework IOKit \
    -framework ServiceManagement \
    -framework IOBluetooth \
    -O \
    -o CGPUMonitor

echo "📦 Packaging CGPUMonitor.app..."
mkdir -p CGPUMonitor.app/Contents/MacOS CGPUMonitor.app/Contents/Resources
cp CGPUMonitor CGPUMonitor.app/Contents/MacOS/CGPUMonitor
chmod +x CGPUMonitor.app/Contents/MacOS/CGPUMonitor
if [ -f AppIcon.icns ]; then
    cp AppIcon.icns CGPUMonitor.app/Contents/Resources/AppIcon.icns
fi
touch CGPUMonitor.app

echo "✅ Build complete! You can run:"
echo "   open CGPUMonitor.app"
