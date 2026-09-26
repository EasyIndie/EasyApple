#!/usr/bin/env bash
# tools/bundle.sh — 原生打包:把 SwiftPM executable 拼成 .app(macOS / iOS 模拟器)
#
# 用法:
#   tools/bundle.sh                        # macOS,release
#   tools/bundle.sh --platform iOSSimulator
#   tools/bundle.sh --config debug
#
# 产物:apps/<App>/.build/bundle/<App>.app
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

PLATFORM="macOS"
CONFIG="release"
APP_NAME="EnvDemo"

while [ $# -gt 0 ]; do
  case "$1" in
    --platform) PLATFORM="$2"; shift 2 ;;
    --config)   CONFIG="$2"; shift 2 ;;
    --app)      APP_NAME="$2"; shift 2 ;;
    *) die "未知参数: $1" ;;
  esac
done

APP_DIR="$REPO_ROOT/apps/$APP_NAME"
[ -d "$APP_DIR" ] || die "找不到 app 目录: $APP_DIR"
cd "$APP_DIR"

BUNDLE_ID="com.easyapple.$(printf '%s' "$APP_NAME" | tr '[:upper:]' '[:lower:]')"
VERSION="$(version_from_props)"
BUNDLE_VERSION="$(bundle_version_from_props)"

# 1) 构建 + 定位可执行文件
case "$PLATFORM" in
  macOS)
    note "构建 macOS($CONFIG)"
    xcrun swift build -c "$CONFIG"
    EXEC="$(xcrun swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"
    ;;
  iOSSimulator|ios-simulator)
    SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
    note "构建 iOS 模拟器($CONFIG,triple=arm64-apple-ios-simulator)"
    xcrun swift build -c "$CONFIG" --triple arm64-apple-ios-simulator --sdk "$SDK"
    EXEC="$(xcrun swift build -c "$CONFIG" --triple arm64-apple-ios-simulator --sdk "$SDK" --show-bin-path)/$APP_NAME"
    ;;
  *) die "不支持的平台: $PLATFORM(支持 macOS / iOSSimulator)" ;;
esac
[ -x "$EXEC" ] || die "找不到可执行文件: $EXEC"

# 2) 拼 .app
BUNDLE="$APP_DIR/.build/bundle/$APP_NAME.app"
rm -rf "$BUNDLE"

case "$PLATFORM" in
  macOS)
    mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
    cp "$EXEC" "$BUNDLE/Contents/MacOS/$APP_NAME"
    INFO="$BUNDLE/Contents/Info.plist"
    ;;
  iOSSimulator|ios-simulator)
    mkdir -p "$BUNDLE"
    cp "$EXEC" "$BUNDLE/$APP_NAME"
    INFO="$BUNDLE/Info.plist"
    ;;
esac

# 3) 写 Info.plist
note "写 Info.plist(版本 $VERSION / CFBundleVersion $BUNDLE_VERSION)"
{
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundleExecutable</key>
	<string>$APP_NAME</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$BUNDLE_VERSION</string>
EOF
  case "$PLATFORM" in
    macOS)
      cat <<EOF
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSHighResolutionCapable</key>
	<true/>
EOF
      ;;
    iOSSimulator|ios-simulator)
      cat <<EOF
	<key>MinimumOSVersion</key>
	<string>17.0</string>
	<key>UIDeviceFamily</key>
	<array>
		<integer>1</integer>
		<integer>2</integer>
	</array>
	<key>UILaunchScreen</key>
	<dict/>
EOF
      ;;
  esac
  cat <<EOF
</dict>
</plist>
EOF
} > "$INFO"

# 4) 校验 plist + ad-hoc 签名
plutil -lint "$INFO" >/dev/null || die "Info.plist 语法错误"
codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || die "codesign 失败"

ok "打包完成: $BUNDLE"
