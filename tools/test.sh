#!/usr/bin/env bash
# tools/test.sh — swift test(宿主机单测)
#   tools/test.sh [AppName]       # 默认 EnvDemo
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

APP="${1:-EnvDemo}"
note "测试 $APP"
cd "$REPO_ROOT/apps/$APP"
xcrun swift test
ok "测试完成"
