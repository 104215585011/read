#!/usr/bin/env bash
set -euo pipefail

echo "================================================="
echo "       StudyOS iPad .ipa Automated Packaging     "
echo "================================================="

# 1. 检查并安装 xcodegen
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_ENV_HINTS=1

if ! command -v xcodegen &> /dev/null; then
    echo "==> [1/5] xcodegen 未安装，正在通过 Homebrew 快速安装 (已跳过全量更新)..."
    brew install xcodegen
else
    echo "==> [1/5] xcodegen 已安装: $(xcodegen --version)"
fi

# 2. 生成 Xcode 原生工程
echo "==> [2/5] 正在生成 StudyOS.xcodeproj 原生工程..."
xcodegen generate

# 兼容性处理：将 xcodegen 生成的高版本工程格式 (77/Xcode 16) 降级为 Xcode 15 兼容模式 (objectVersion 56)
echo "==> 调整 Xcode 工程兼容性格式为 Xcode 15 (objectVersion = 56)..."
sed -i '' 's/objectVersion = [0-9]*/objectVersion = 56/g' StudyOS.xcodeproj/project.pbxproj
sed -i '' 's/compatibilityVersion = "Xcode [^"]*"/compatibilityVersion = "Xcode 14.0"/g' StudyOS.xcodeproj/project.pbxproj

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

if [ -d "build/Release-iphoneos/StudyOS.app" ]; then
    APP_BUNDLE_PATH="build/Release-iphoneos/StudyOS.app"
else
    APP_BUNDLE_PATH=$(find build -name "StudyOS.app" -type d | grep -v "\.build" | head -n 1)
fi

if [ -z "$APP_BUNDLE_PATH" ] || [ ! -d "$APP_BUNDLE_PATH" ]; then
    echo "错误：未在 build 目录中找到 StudyOS.app！"
    exit 1
fi

echo "找到构建产物 App Bundle: $APP_BUNDLE_PATH"
cp -r "$APP_BUNDLE_PATH" Payload/

# 强制写入安装器要求的真实 Bundle 元数据，避免 Xcode 模板变量进入 IPA
PLIST_PATH="Payload/StudyOS.app/Info.plist"
cp Config/Info.plist "$PLIST_PATH"

set_plist_string() {
    local key="$1"
    local value="$2"
    /usr/libexec/PlistBuddy -c "Set :${key} ${value}" "$PLIST_PATH" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :${key} string ${value}" "$PLIST_PATH"
}

set_plist_bool() {
    local key="$1"
    local value="$2"
    /usr/libexec/PlistBuddy -c "Set :${key} ${value}" "$PLIST_PATH" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :${key} bool ${value}" "$PLIST_PATH"
}

set_plist_string "CFBundleDevelopmentRegion" "zh-Hans"
set_plist_string "CFBundleDisplayName" "StudyOS"
set_plist_string "CFBundleExecutable" "StudyOS"
set_plist_string "CFBundleIdentifier" "com.studyos.app"
set_plist_string "CFBundleInfoDictionaryVersion" "6.0"
set_plist_string "CFBundleName" "StudyOS"
set_plist_string "CFBundlePackageType" "APPL"
set_plist_string "CFBundleShortVersionString" "1.0.0"
set_plist_string "CFBundleVersion" "1"
set_plist_string "MinimumOSVersion" "17.0"
set_plist_string "DTPlatformName" "iphoneos"
set_plist_string "CFBundleSignature" "????"
set_plist_bool "LSRequiresIPhoneOS" "true"

/usr/libexec/PlistBuddy -c "Delete :CFBundleSupportedPlatforms" "$PLIST_PATH" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleSupportedPlatforms array" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Add :CFBundleSupportedPlatforms:0 string iPhoneOS" "$PLIST_PATH"

/usr/libexec/PlistBuddy -c "Delete :UIDeviceFamily" "$PLIST_PATH" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :UIDeviceFamily array" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Add :UIDeviceFamily:0 integer 1" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Add :UIDeviceFamily:1 integer 2" "$PLIST_PATH"

/usr/libexec/PlistBuddy -c "Delete :UIRequiredDeviceCapabilities" "$PLIST_PATH" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :UIRequiredDeviceCapabilities array" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Add :UIRequiredDeviceCapabilities:0 string arm64" "$PLIST_PATH"

plutil -lint "$PLIST_PATH"

if grep -q '\$(' "$PLIST_PATH"; then
    echo "错误：Info.plist 仍包含未展开的 Xcode 构建变量，拒绝生成无效 IPA。"
    cat "$PLIST_PATH"
    exit 1
fi

# 写入 iOS 标配的 PkgInfo 签名标识文件
echo -n "APPL????" > Payload/StudyOS.app/PkgInfo

# 验证并赋权可执行文件
if [ ! -f "Payload/StudyOS.app/StudyOS" ]; then
    echo "错误：Payload/StudyOS.app 内缺少 StudyOS 二进制执行文件！"
    exit 1
fi
chmod +x Payload/StudyOS.app/StudyOS

# 打印 App Bundle 详细结构以便验证
echo "==> Payload/StudyOS.app 文件清单："
ls -la Payload/StudyOS.app

# 压缩为标准 IPA
zip -r -q StudyOS.ipa Payload

echo "==> 验证 IPA 内部 Info.plist..."
unzip -p StudyOS.ipa Payload/StudyOS.app/Info.plist > /tmp/studyos-ipa-info.plist
plutil -lint /tmp/studyos-ipa-info.plist

if grep -q '\$(' /tmp/studyos-ipa-info.plist; then
    echo "错误：IPA 内部 Info.plist 仍包含未展开变量，打包失败。"
    cat /tmp/studyos-ipa-info.plist
    exit 1
fi

if [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' /tmp/studyos-ipa-info.plist)" != "StudyOS" ]; then
    echo "错误：IPA 内部 CFBundleExecutable 不正确。"
    exit 1
fi

if [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' /tmp/studyos-ipa-info.plist)" != "com.studyos.app" ]; then
    echo "错误：IPA 内部 CFBundleIdentifier 不正确。"
    exit 1
fi

rm -rf Payload

echo "==> [5/5] 打包成功！输出工件："
ls -lh StudyOS.ipa
echo "================================================="
echo " StudyOS.ipa 打包完成，可直接用于 Sideloadly 侧载实测 "
echo "================================================="
