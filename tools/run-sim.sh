#!/usr/bin/env bash
# tools/run-sim.sh — 打包并在 iOS 模拟器上运行(一条命令闭环)
#
# 用法:
#   tools/run-sim.sh                          # 自动挑设备(已启动 iPhone > iPhone 17 > 最新)
#   tools/run-sim.sh --app MyApp              # 指定应用(apps/ 下多个应用时必填)
#   tools/run-sim.sh --device "iPhone 18 Pro" # 按名字(子串)选
#   tools/run-sim.sh --udid <UDID>            # 按 UDID 选(同名设备多 runtime 时最稳)
#   tools/run-sim.sh --no-bundle              # 复用已有 .app
#   tools/run-sim.sh --screenshot /tmp/a.png  # 启动后截图
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

APP_NAME=""
DEVICE_QUERY="${SIM_DEVICE:-}"
DO_BUNDLE=1
SHOT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --device) DEVICE_QUERY="$2"; shift 2 ;;
    --udid) DEVICE_QUERY="$2"; shift 2 ;;
    --app) APP_NAME="$2"; shift 2 ;;
    --no-bundle) DO_BUNDLE=0; shift ;;
    --screenshot) SHOT="$2"; shift 2 ;;
    *) die "未知参数: $1" ;;
  esac
done

[ -n "$APP_NAME" ] || APP_NAME="$(default_app)"

BUNDLE="$REPO_ROOT/apps/$APP_NAME/.build/bundle/$APP_NAME.app"
BUNDLE_ID="com.easyapple.$(printf '%s' "$APP_NAME" | tr '[:upper:]' '[:lower:]')"

if [ "$DO_BUNDLE" = 1 ]; then
  "$REPO_ROOT/tools/bundle.sh" --platform iOSSimulator --app "$APP_NAME"
fi
[ -d "$BUNDLE" ] || die "找不到 .app: $BUNDLE(先跑 tools/bundle.sh --platform iOSSimulator)"

UDID="$(simctl_resolve_device "$DEVICE_QUERY")"
note "设备: $UDID"

if ! xcrun simctl list devices | grep -F "$UDID" | grep -q "(Booted)"; then
  note "启动模拟器…"
  xcrun simctl boot "$UDID" 2>/dev/null || true
  run_timeout 180 xcrun simctl bootstatus "$UDID" -b >/dev/null
fi

note "安装 $APP_NAME.app"
run_timeout 180 xcrun simctl install "$UDID" "$BUNDLE"

note "启动 $BUNDLE_ID"
run_timeout 120 xcrun simctl launch "$UDID" "$BUNDLE_ID"

if [ -n "$SHOT" ]; then
  sleep 3
  run_timeout 60 xcrun simctl io "$UDID" screenshot "$SHOT" >/dev/null
  ok "截图: $SHOT"
fi
ok "已在 $UDID 上启动 $APP_NAME"
