#!/bin/bash

# 测试运行脚本
# 用于 ScreenCapture 项目的测试验证

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================="
echo "ScreenCapture OCR 测试脚本"
echo "========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 验证编译
echo -e "${YELLOW}[1/3] 验证编译...${NC}"
if xcodebuild -project ScreenCapture.xcodeproj \
    -scheme ScreenCapture \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGN_IDENTITY="" \
    build > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 编译通过${NC}"
else
    echo -e "${RED}✗ 编译失败${NC}"
    exit 1
fi

echo ""

# 2. 运行 SwiftLint（仅检查新创建的 OCR 文件）
echo -e "${YELLOW}[2/3] 运行 SwiftLint...${NC}"
if command -v swiftlint &> /dev/null; then
    # 只检查新创建的 OCR 相关文件
    OCR_FILES=(
        "ScreenCapture/Models/OCRResult.swift"
        "ScreenCapture/Services/OCREngine.swift"
        "ScreenCapture/Errors/ScreenCaptureError.swift"
    )

    HAS_ERROR=false
    for file in "${OCR_FILES[@]}"; do
        if [ -f "$file" ]; then
            FILE_RESULT=$(swiftlint lint --path "$file" 2>&1 || true)
            if echo "$FILE_RESULT" | grep -q "error:"; then
                echo -e "${RED}✗ $file 有错误${NC}"
                echo "$FILE_RESULT"
                HAS_ERROR=true
            fi
        fi
    done

    if [ "$HAS_ERROR" = true ]; then
        exit 1
    else
        echo -e "${GREEN}✓ SwiftLint 通过（OCR 相关文件无错误）${NC}"
    fi
else
    echo -e "${YELLOW}⚠ SwiftLint 未安装，跳过${NC}"
fi

echo ""

# 3. 测试文件验证
echo -e "${YELLOW}[3/3] 验证测试文件...${NC}"

TEST_FILES=(
    "ScreenCaptureTests/OCRResultTests.swift"
    "ScreenCaptureTests/OCREngineTests.swift"
    "ScreenCaptureTests/ScreenCaptureTests.swift"
)

ALL_EXISTS=true
for file in "${TEST_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (不存在)"
        ALL_EXISTS=false
    fi
done

if [ "$ALL_EXISTS" = true ]; then
    echo -e "${GREEN}✓ 所有测试文件存在${NC}"
else
    echo -e "${RED}✗ 部分测试文件缺失${NC}"
    exit 1
fi

echo ""
echo "========================================="
echo -e "${GREEN}所有检查通过！${NC}"
echo "========================================="
echo ""
echo "注意：由于项目使用 Xcode 项目结构（非 SPM），"
echo "无法直接运行 'swift test'。请使用以下方式运行测试："
echo ""
echo "  1. 在 Xcode 中按 Cmd+U"
echo "  2. 或使用: xcodebuild test -project ScreenCapture.xcodeproj \\"
echo "                  -scheme ScreenCapture \\"
echo "                  -destination 'platform=macOS'"
echo ""
