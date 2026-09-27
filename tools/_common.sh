#!/usr/bin/env bash
# tools/_common.sh — 所有脚本共用的基座(被 source,不要直接执行)
#
# 约定:
#   - 平台固定 macOS(arm64),无跨平台分支
#   - 工具统一用 `xcrun swift` / `xcrun xcodebuild` / `xcrun simctl`(规避 swiftly PATH 坑)
#   - 输出函数:note / ok / skip / die

set -u

# 仓库根目录(本文件在 tools/ 下)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Xcode 开发者目录(默认取 xcode-select;可用环境变量覆盖)
if [ -z "${DEVELOPER_DIR:-}" ]; then
  DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
fi
export DEVELOPER_DIR

note() { printf '\033[1;34m[note]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ ok ]\033[0m %s\n' "$*"; }
skip() { printf '\033[1;33m[skip]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[die ]\033[0m %s\n' "$*" >&2; exit 1; }

# 从 version.properties 读版本(唯一来源)
version_from_props() {
  local v
  v="$(grep -E '^version=' "$REPO_ROOT/version.properties" 2>/dev/null | head -1 | cut -d= -f2 | tr -d '[:space:]')"
  [ -n "$v" ] || die "version.properties 里没有 version= 行"
  printf '%s' "$v"
}

# SemVer → CFBundleVersion(MAJOR*10000 + MINOR*100 + PATCH)
bundle_version_from_props() {
  local v major minor patch
  v="$(version_from_props)"
  major="$(printf '%s' "$v" | cut -d. -f1)"
  minor="$(printf '%s' "$v" | cut -d. -f2)"
  patch="$(printf '%s' "$v" | cut -d. -f3)"
  printf '%d' "$(( major*10000 + minor*100 + patch ))"
}

# 按设备名解析 UDID(取第一个匹配的 available 设备)
simctl_udid() {
  local name="$1" udid
  udid="$(xcrun simctl list devices available | grep -F "$name (" | head -1 \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)"
  [ -n "$udid" ] || die "找不到模拟器设备: $name(用 tools/sim.sh list 查看)"
  printf '%s' "$udid"
}

# 编译并缓存原生 OCR 工具 tools/uiscan.swift(源码更新时自动重编)。
# 只向 stdout 输出二进制路径;日志走 stderr(以便在 $(...) 里安全使用)。
ensure_uiscan() {
  local src="$REPO_ROOT/tools/uiscan.swift"
  local bin="$REPO_ROOT/.tmp/tools-cache/uiscan"
  if [ ! -x "$bin" ] || [ "$src" -nt "$bin" ]; then
    mkdir -p "$(dirname "$bin")"
    note "编译 uiscan(原生 OCR)…" >&2
    xcrun swiftc -O "$src" -o "$bin" >&2 || die "uiscan 编译失败"
  fi
  printf '%s' "$bin"
}

# 判断 .app 是否为 ad-hoc(未真实)签名:是→返回 0,否→返回 1。
# 真实签名(Developer ID / App Store)会有 Team ID;ad-hoc 则为 Signature=adhoc / TeamIdentifier=not set。
is_adhoc_signed() {
  local app="$1" info
  [ -d "$app" ] || return 1
  info="$(codesign -dv --verbose=4 "$app" 2>&1 || true)"
  printf '%s' "$info" | grep -q 'Signature=adhoc' && return 0
  printf '%s' "$info" | grep -q 'TeamIdentifier=not set' && return 0
  return 1
}
