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
