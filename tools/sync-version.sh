#!/usr/bin/env bash
# tools/sync-version.sh — 版本唯一来源(D8)的输出与校验
#
#   tools/sync-version.sh           # 打印 version / CFBundleVersion
#   tools/sync-version.sh --check   # 校验(严格 SemVer + 源码里无版本字面量)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

v="$(version_from_props)"
bv="$(bundle_version_from_props)"

if [ "${1:-}" = "--check" ]; then
  printf '%s' "$v" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' || die "version 不是严格 SemVer: $v"
  # 固定串匹配(-F):版本号里的 `.` 不能当正则通配符,否则含 `3` 的版本会误命中 ANSI 转义里的 `033[0`
  hits="$(grep -rnF --exclude-dir=.build --exclude-dir=.git -- "$v" "$REPO_ROOT/apps" "$REPO_ROOT/tools" 2>/dev/null || true)"
  [ -z "$hits" ] || die "源码里出现版本字面量 $v:
$hits"
  ok "版本校验通过: version=$v  CFBundleVersion=$bv"
else
  echo "version=$v"
  echo "CFBundleVersion=$bv"
fi
