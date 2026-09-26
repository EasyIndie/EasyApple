#!/usr/bin/env bash
# tools/doctor.sh — 环境自检(Air 上的体检命令)
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

PASS=0; WARN=0; FAIL=0
row() { printf '  %-22s %s\n' "$1" "$2"; }
c_ok()   { row "$1" "✅ $2"; PASS=$((PASS+1)); }
c_warn() { row "$1" "⚠️  $2"; WARN=$((WARN+1)); }
c_bad()  { row "$1" "❌ $2"; FAIL=$((FAIL+1)); }

echo "== EasyApple doctor =="

# macOS
if [ "$(sw_vers -productName 2>/dev/null)" = "macOS" ]; then
  c_ok "macOS" "$(sw_vers -productVersion) ($(sw_vers -buildVersion))"
else
  c_bad "macOS" "非 macOS 或缺少 sw_vers"
fi

# 架构
arch="$(uname -m)"
if [ "$arch" = "arm64" ]; then c_ok "架构" "arm64"; else c_bad "架构" "$arch(须 arm64)"; fi

# xcode-select
dev="$(xcode-select -p 2>/dev/null || true)"
case "$dev" in
  */Xcode*.app/Contents/Developer) c_ok "xcode-select" "$dev" ;;
  *CommandLineTools*) c_bad "xcode-select" "$dev(仍是 CLT;先 xcodes select 27.0)" ;;
  *) c_bad "xcode-select" "${dev:-未设置}" ;;
esac

# xcodebuild
if xcrun xcodebuild -version >/dev/null 2>&1; then
  c_ok "xcodebuild" "$(xcrun xcodebuild -version | head -1)"
else
  c_bad "xcodebuild" "不可用(需完整 Xcode + xcode-select)"
fi

# iOS 模拟器 SDK
sdk="$(xcrun --sdk iphonesimulator --show-sdk-path 2>/dev/null || true)"
if [ -n "$sdk" ]; then c_ok "iOS 模拟器 SDK" "$(basename "$sdk")"; else c_bad "iOS 模拟器 SDK" "找不到"; fi

# Swift
if xcrun swift --version >/dev/null 2>&1; then
  c_ok "Swift" "$(xcrun swift --version 2>/dev/null | sed -n 's/.*Apple Swift version \([0-9][0-9.]*\).*/\1/p' | head -1)"
else
  c_bad "Swift" "xcrun swift 不可用"
fi

# iOS runtime
rt="$(xcrun simctl list runtimes 2>/dev/null | grep -E '^iOS ' | tail -1 || true)"
if [ -n "$rt" ]; then c_ok "iOS runtime" "$(printf '%s' "$rt" | awk '{print $1, $2}')"; else c_bad "iOS runtime" "未安装(装 Xcode 后 xcodes runtimes install)"; fi

# 模拟器设备
n="$(xcrun simctl list devices available 2>/dev/null | grep -cE '(iPhone|iPad) ' || true)"
if [ "${n:-0}" -gt 0 ]; then c_ok "模拟器设备" "$n 台可用"; else c_warn "模拟器设备" "无"; fi

# xcodes(可选,仅装机用)
if command -v xcodes >/dev/null 2>&1; then
  c_ok "xcodes(装机)" "$(xcodes version 2>/dev/null)"
else
  c_warn "xcodes(装机)" "未装(bootstrap.sh 会装)"
fi

echo
echo "== 通过 $PASS / 警告 $WARN / 失败 $FAIL =="
[ "$FAIL" -eq 0 ]
