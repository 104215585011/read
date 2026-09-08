#!/usr/bin/env bash
set -euo pipefail

echo "================================================="
echo "       StudyOS iPad .ipa Automated Packaging     "
echo "================================================="

# 1. 检查并安装 xcodegen
if ! command -v xcodegen &> /dev/null; then
    echo "==> [1/5] xcodegen 未安装，正在通过 Homebrew 安装..."
    brew install xcodegen
else
    echo "==> [1/5] xcodegen 已安装: $(xcodegen --version)"
fi

# 2. 生成 Xcode 原生工程
echo "==> [2/5] 正在生成 StudyOS.xcodeproj 原生工程..."
xcodegen generate

# 3. 编译真机 Release 版本
echo "==> [3/5] 正在编译真机 Release 二进制目标 (iphoneos arm64)..."
xcodebuild build \
  -project StudyOS.xcodeproj \
  -scheme StudyOS \
  -sdk iphoneos \
  -configuration Release \
  -destination "generic/platform=iOS" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  BUILD_DIR="./build"

# 4. 构建 Payload 并打包成 IPA
echo "==> [4/5] 正在构建 Payload 目录并打包 IPA..."
rm -rf Payload StudyOS.ipa
mkdir -p Payload

APP_BUNDLE_PATH=$(find build/Release-iphoneos -name "StudyOS.app" -type d | head -n 1)
if [ -z "$APP_BUNDLE_PATH" ] || [ ! -d "$APP_BUNDLE_PATH" ]; then
    echo "错误：未在 build/Release-iphoneos 中找到 StudyOS.app！"
    exit 1
fi

echo "找到构建产物 App Bundle: $APP_BUNDLE_PATH"
cp -r "$APP_BUNDLE_PATH" Payload/

# 验证可执行文件
if [ ! -f "Payload/StudyOS.app/StudyOS" ]; then
    echo "错误：Payload/StudyOS.app 内缺少 StudyOS 二进制执行文件！"
    exit 1
fi

# 压缩为标准 IPA
zip -r -q StudyOS.ipa Payload
rm -rf Payload

echo "==> [5/5] 打包成功！输出工件："
ls -lh StudyOS.ipa
echo "================================================="
echo " StudyOS.ipa 打包完成，可直接用于 Sideloadly 侧载实测 "
echo "================================================="
