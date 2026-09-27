#!/usr/bin/env bash
# tools/test.sh — swift test(宿主机单测)
#   tools/test.sh                  # 测试 apps/ 下所有应用
#   tools/test.sh App1 App2        # 只测试指定应用
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

apps="$(resolve_apps "$@")"
[ -n "$apps" ] || die "apps/ 下没有任何应用(先用 tools/new-app.sh <Name> 生成)"

count=0
while IFS= read -r APP; do
  [ -n "$APP" ] || continue
  note "测试 $APP"
  ( cd "$REPO_ROOT/apps/$APP" && xcrun swift test )
  count=$((count + 1))
done <<< "$apps"

ok "测试完成($count 个应用)"
