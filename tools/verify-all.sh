#!/usr/bin/env bash
# tools/verify-all.sh — 总验收:遍历 apps/ 下所有应用
#   doctor → sync-version → 每个应用:[build → test → run-sim → ui-dump → ui-assert]
#
# 用法:
#   tools/verify-all.sh              # 全部应用
#   tools/verify-all.sh EnvDemo      # 只验收指定应用
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

PASS=0; FAIL=0
step() {
  local name="$1"; shift
  note "▶ $name"
  if "$@"; then ok "$name"; PASS=$((PASS+1)); else printf '\033[1;31m[FAIL]\033[0m %s\n' "$name" >&2; FAIL=$((FAIL+1)); fi
}

step "doctor"       bash "$REPO_ROOT/tools/doctor.sh"
step "sync-version" bash "$REPO_ROOT/tools/sync-version.sh" --check

apps="$(resolve_apps "$@")"
[ -n "$apps" ] || die "apps/ 下没有任何应用(先用 tools/new-app.sh <Name> 生成)"

while IFS= read -r APP; do
  [ -n "$APP" ] || continue
  note "──────── 应用: $APP ────────"
  step "build($APP)"   bash "$REPO_ROOT/tools/build.sh" "$APP"
  step "test($APP)"    bash "$REPO_ROOT/tools/test.sh" "$APP"
  step "run-sim($APP)" bash "$REPO_ROOT/tools/run-sim.sh" --app "$APP"
  step "ui-dump($APP)" bash "$REPO_ROOT/tools/ui-dump.sh" --out "$REPO_ROOT/.tmp/ui-$APP.png"
  if has_ui_assertions "$APP"; then
    step "ui-assert($APP)" bash "$REPO_ROOT/tools/ui-assert.sh" --app "$APP"
  else
    skip "ui-assert($APP)(无 apps/$APP/ui-assertions.txt,跳过)"
  fi
done <<< "$apps"

echo
echo "== 通过 $PASS / 失败 $FAIL =="
[ "$FAIL" -eq 0 ]
