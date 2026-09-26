#!/usr/bin/env bash
# tools/build.sh — swift build(macOS 宿主机)
#   tools/build.sh [AppName]      # 默认 EnvDemo
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

APP="${1:-EnvDemo}"
bash "$REPO_ROOT/tools/sync-version.sh" --check

note "构建 $APP(macOS,debug)"
cd "$REPO_ROOT/apps/$APP"
xcrun swift build
ok "构建完成"
