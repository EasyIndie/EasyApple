#!/usr/bin/env bash
# tools/run-sim.sh — 打包并在 iOS 模拟器上运行(一条命令闭环)
#
# 用法:
#   tools/run-sim.sh                          # 默认设备 iPhone 17
#   tools/run-sim.sh --device "iPhone 18 Pro"
#   tools/run-sim.sh --no-bundle              # 复用已有 .app
#   tools/run-sim.sh --screenshot /tmp/a.png  # 启动后截图
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

APP_NAME="EnvDemo"
DEVICE_NAME="${SIM_DEVICE:-iPhone 17}"
DO_BUNDLE=1
SHOT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --device) DEVICE_NAME="$2"; shift 2 ;;
    --app) APP_NAME="$2"; shift 2 ;;
    --no-bundle) DO_BUNDLE=0; shift ;;
    --screenshot) SHOT="$2"; shift 2 ;;
    *) die "未知参数: $1" ;;
  esac
done

BUNDLE="$REPO_ROOT/apps/$APP_NAME/.build/bundle/$APP_NAME.app"
BUNDLE_ID="com.easyapple.$(printf '%s' "$APP_NAME" | tr '[:upper:]' '[:lower:]')"

if [ "$DO_BUNDLE" = 1 ]; then
  "$REPO_ROOT/tools/bundle.sh" --platform iOSSimulator --app "$APP_NAME"
fi
[ -d "$BUNDLE" ] || die "找不到 .app: $BUNDLE(先跑 tools/bundle.sh --platform iOSSimulator)"

UDID="$(xcrun simctl list devices available | grep -F "$DEVICE_NAME (" | head -1 \
  | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)"
[ -n "$UDID" ] || die "找不到模拟器设备: $DEVICE_NAME(用 tools/sim.sh list 查看)"
note "设备: $DEVICE_NAME ($UDID)"

if ! xcrun simctl list devices | grep -F "$UDID" | grep -q "(Booted)"; then
  note "启动模拟器…"
  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null
fi

note "安装 $APP_NAME.app"
xcrun simctl install "$UDID" "$BUNDLE"

note "启动 $BUNDLE_ID"
xcrun simctl launch "$UDID" "$BUNDLE_ID"

if [ -n "$SHOT" ]; then
  sleep 3
  xcrun simctl io "$UDID" screenshot "$SHOT" >/dev/null
  ok "截图: $SHOT"
fi
ok "已在 $DEVICE_NAME 上启动 $APP_NAME"
