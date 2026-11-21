#!/usr/bin/env bash
# tools/test-template.sh — 模板冒烟:生成一个临时应用 → 构建 + 单测 → 删除
#
#   tools/test-template.sh
#
# 为什么需要它:template/ 不参与 apps/ 的常规构建,改坏了平时不会有人发现。
# 这里用真实链路(`new-app.sh` → `swift build` → `swift test`)跑一遍。
# 不碰 apps/,临时目录在 .tmp/ 下,结束自动清理。
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

TMP_ROOT="$REPO_ROOT/.tmp/template-check"
APP="TemplateCheck"

rm -rf "$TMP_ROOT"
mkdir -p "$TMP_ROOT"
trap 'rm -rf "$TMP_ROOT"' EXIT

note "生成临时应用 $APP(.tmp/template-check)"
bash "$REPO_ROOT/tools/new-app.sh" "$APP" --dest "$TMP_ROOT" >/dev/null

APP_DIR="$TMP_ROOT/$APP"
[ -f "$APP_DIR/Package.swift" ] || die "生成失败: 找不到 $APP_DIR/Package.swift"

note "构建模板应用(macOS,debug)"
(cd "$APP_DIR" && xcrun swift build)

note "跑模板单测"
(cd "$APP_DIR" && xcrun swift test)

ok "模板冒烟通过($APP 构建 + 单测)"
