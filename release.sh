#!/bin/bash
VERSION="1.0.2"
PROJECT_PATH="/Users/hubo/Projects/transframe"
XCODE_PROJ="$PROJECT_PATH/TransFrame.xcodeproj"

echo "🚀 开始发布版本 v$VERSION..."
rm -rf "$PROJECT_PATH/build_artifacts"
rm -f "$PROJECT_PATH/TransFrame-v$VERSION-arm64.zip"
rm -f "$PROJECT_PATH/TransFrame-v$VERSION-x86_64.zip"

echo "🏗️ 正在编译 arm64 版本..."
xcodebuild -project "$XCODE_PROJ" -scheme TransFrame -configuration Release -arch arm64 -derivedDataPath "$PROJECT_PATH/build_artifacts/arm64" -quiet
mkdir -p "$PROJECT_PATH/build_artifacts/release_arm64"
cp -R "$PROJECT_PATH/build_artifacts/arm64/Build/Products/Release/TransFrame.app" "$PROJECT_PATH/build_artifacts/release_arm64/"
(cd "$PROJECT_PATH/build_artifacts/release_arm64" && zip -r "../../TransFrame-v$VERSION-arm64.zip" TransFrame.app > /dev/null)

echo "🏗️ 正在编译 x86_64 版本..."
xcodebuild -project "$XCODE_PROJ" -scheme TransFrame -configuration Release -arch x86_64 -derivedDataPath "$PROJECT_PATH/build_artifacts/x86_64" -quiet
mkdir -p "$PROJECT_PATH/build_artifacts/release_x86_64"
cp -R "$PROJECT_PATH/build_artifacts/x86_64/Build/Products/Release/TransFrame.app" "$PROJECT_PATH/build_artifacts/release_x86_64/"
(cd "$PROJECT_PATH/build_artifacts/release_x86_64" && zip -r "../../TransFrame-v$VERSION-x86_64.zip" TransFrame.app > /dev/null)

echo "📤 正在提交代码..."
git add .
git commit -m "feat: 发布 v$VERSION 版本 - 彻底修复 Retina 缩放并调大译文字号"
git push origin main

echo "🏷️ 正在创建 Release..."
gh release create "v$VERSION" \
  "$PROJECT_PATH/TransFrame-v$VERSION-arm64.zip" \
  "$PROJECT_PATH/TransFrame-v$VERSION-x86_64.zip" \
  --title "v$VERSION" \
  --notes "Fixed Retina scaling and increased translation font size."

echo "✅ 发布完成！"
