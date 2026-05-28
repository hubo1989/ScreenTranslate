#!/bin/bash
set -e

# Configuration
VERSION="1.5.1"
PROJECT_PATH="$(pwd)"
XCODE_PROJ="$PROJECT_PATH/TransFrame.xcodeproj"
DMG_TEMP_DIR="$PROJECT_PATH/build_artifacts/dmg_temp"
DMG_NAME="TransFrame-v$VERSION.dmg"
DMG_PATH="$PROJECT_PATH/$DMG_NAME"

echo "🚀 开始制作 DMG 安装包..."

# 1. 清理旧的编译和打包产物
rm -rf "$PROJECT_PATH/build_artifacts/dmg"
rm -rf "$DMG_TEMP_DIR"
rm -f "$DMG_PATH"

# 2. 编译 Release 版本 (使用默认/当前架构)
echo "🏗️ 正在编译 Release 版本..."
xcodebuild -project "$XCODE_PROJ" -scheme TransFrame -configuration Release -derivedDataPath "$PROJECT_PATH/build_artifacts/dmg" -quiet

# 3. 创建临时文件夹结构
echo "📁 准备 DMG 目录结构..."
mkdir -p "$DMG_TEMP_DIR"

# 复制 .app 到临时目录
APP_PATH="$PROJECT_PATH/build_artifacts/dmg/Build/Products/Release/TransFrame.app"
if [ ! -d "$APP_PATH" ]; then
    APP_PATH="$PROJECT_PATH/build/Products/Release/TransFrame.app"
fi
if [ ! -d "$APP_PATH" ]; then
    APP_PATH="$PROJECT_PATH/Build/Products/Release/TransFrame.app"
fi

if [ ! -d "$APP_PATH" ]; then
    # 模糊查找
    APP_PATH=$(find "$PROJECT_PATH/build" "$PROJECT_PATH/Build" "$PROJECT_PATH/build_artifacts" -name "TransFrame.app" -type d | head -n 1)
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "❌ 错误: 未找到编译好的 TransFrame.app"
    exit 1
fi

echo "Found app at: $APP_PATH"
cp -R "$APP_PATH" "$DMG_TEMP_DIR/"

# 创建 Applications 软链接
ln -s /Applications "$DMG_TEMP_DIR/Applications"

# 4. 使用 hdiutil 生成 DMG
echo "📦 正在生成 DMG 镜像..."
# 创建临时可写 DMG
TEMP_DMG="$PROJECT_PATH/build_artifacts/temp.dmg"
rm -f "$TEMP_DMG"

hdiutil create -srcfolder "$DMG_TEMP_DIR" -volname "TransFrame" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 300m "$TEMP_DMG"

# 挂载 DMG 调整布局 (可选，这里使用简单的默认挂载与静默转换即可，
# 若需要高级背景图和位置，通常需要 AppleScript，但由于 CLI 环境，我们提供一个标准且高兼容性的 DMG)
# 转换成压缩的、只读的 DMG
echo "💾 正在压缩 DMG..."
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"

# 清理临时文件
rm -f "$TEMP_DMG"
rm -rf "$DMG_TEMP_DIR"

echo "✅ DMG 制作完成: $DMG_PATH"
