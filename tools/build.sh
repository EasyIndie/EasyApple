#!/usr/bin/env bash
# tools/build.sh — swift build(macOS 宿主机)
#   tools/build.sh                 # 构建 apps/ 下所有应用
#   tools/build.sh App1 App2       # 只构建指定应用
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

bash "$REPO_ROOT/tools/sync-version.sh" --check

apps="$(resolve_apps "$@")"
[ -n "$apps" ] || die "apps/ 下没有任何应用(先用 tools/new-app.sh <Name> 生成)"

count=0
while IFS= read -r APP; do
  [ -n "$APP" ] || continue
  note "构建 $APP(macOS,debug)"
  ( cd "$REPO_ROOT/apps/$APP" && xcrun swift build )
  count=$((count + 1))
done <<< "$apps"

ok "构建完成($count 个应用)"
