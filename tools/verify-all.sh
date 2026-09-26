#!/usr/bin/env bash
# tools/verify-all.sh — 总验收:doctor → sync-version → build → test → run-sim → ui-dump
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
step "build"        bash "$REPO_ROOT/tools/build.sh"
step "test"         bash "$REPO_ROOT/tools/test.sh"
step "run-sim"      bash "$REPO_ROOT/tools/run-sim.sh"
step "ui-dump"      bash "$REPO_ROOT/tools/ui-dump.sh"

echo
echo "== 通过 $PASS / 失败 $FAIL =="
[ "$FAIL" -eq 0 ]
