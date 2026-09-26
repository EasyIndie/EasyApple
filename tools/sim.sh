#!/usr/bin/env bash
# tools/sim.sh — simctl 常用操作封装
#
# 用法:
#   tools/sim.sh list                       # 可用设备
#   tools/sim.sh runtimes                   # 已装 runtime
#   tools/sim.sh boot "iPhone 17"           # 启动(按名字或 UDID)
#   tools/sim.sh install <udid> <app路径>
#   tools/sim.sh launch <udid> <bundleid>
#   tools/sim.sh screenshot <udid> <文件>
#   tools/sim.sh download-runtime [iOS|visionOS]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

cmd="${1:-}"; shift || true

find_udid() {
  xcrun simctl list devices available | grep -F "$1 (" | head -1 \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1
}

case "$cmd" in
  list)      xcrun simctl list devices available ;;
  runtimes)  xcrun simctl list runtimes ;;
  boot)
    name="${1:?用法: sim.sh boot <设备名或UDID>}"
    udid="$(find_udid "$name")"; [ -n "$udid" ] || udid="$name"
    xcrun simctl bootstatus "$udid" -b >/dev/null && ok "已启动: $name"
    ;;
  install)   xcrun simctl install "$1" "$2" && ok "已安装: $2" ;;
  launch)    xcrun simctl launch "$1" "$2" ;;
  screenshot) xcrun simctl io "$1" screenshot "$2" >/dev/null && ok "截图: $2" ;;
  download-runtime) xcrun xcodebuild -downloadPlatform "${1:-iOS}" ;;
  ""|help|-h|--help) sed -n '2,15p' "$0" ;;
  *) die "未知子命令: $cmd(用 sim.sh help)" ;;
esac
