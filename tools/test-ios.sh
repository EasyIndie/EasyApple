#!/usr/bin/env bash
# tools/test-ios.sh — 在 iOS 模拟器上跑单测(SwiftPM 包,不需要 .xcodeproj)
#
# 原理:Xcode 会为 SwiftPM 包自动生成聚合 scheme `<包名>-Package`,它带 test action。
#       `xcodebuild test -scheme <包名>-Package -destination '…Simulator…'` 就能把
#       `.testTarget` 跑在 iOS 运行时里(UIKit/真机语义、XCTest.measure 性能基线)。
#       ⚠️ 不能用 `-scheme <目标名>`(报 "not configured for the test action")。
#
# 用法:
#   tools/test-ios.sh                       # 遍历 apps/ 下所有应用
#   tools/test-ios.sh EnvDemo               # 只测指定应用
#   tools/test-ios.sh --device "iPhone 17"  # 指定模拟器(默认 $SIM_DEVICE 或 iPhone 17)
#   tools/test-ios.sh --filter EnvDemoCoreTests/EnvironmentReportTests
#   tools/test-ios.sh --coverage            # 打开覆盖率并打印报告
#
# 产物:apps/<App>/.build/ios-test/result.xcresult(JSON 可用 xcresulttool 读)
# 退出码:0 全部通过;1 有失败
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

DEVICE="${SIM_DEVICE:-iPhone 17}"
FILTER=""
COVERAGE=0
APPS_ARG=()

while [ $# -gt 0 ]; do
  case "$1" in
    --device) DEVICE="$2"; shift 2 ;;
    --filter) FILTER="$2"; shift 2 ;;
    --coverage) COVERAGE=1; shift ;;
    -h|--help) sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "未知参数: $1" ;;
    *) APPS_ARG+=("$1"); shift ;;
  esac
done

apps="$(resolve_apps ${APPS_ARG[@]+"${APPS_ARG[@]}"})"
[ -n "$apps" ] || die "apps/ 下没有任何应用(先用 tools/new-app.sh <Name> 生成)"

UDID="$(simctl_udid "$DEVICE")"
note "模拟器: $DEVICE ($UDID)"

# 从 Package.swift 读包名(xcodebuild 的聚合 scheme 是 `<包名>-Package`)
package_name() {
  grep -m1 -E 'name:[[:space:]]*"' "$REPO_ROOT/apps/$1/Package.swift" 2>/dev/null \
    | sed -E 's/.*name:[[:space:]]*"([^"]+)".*/\1/'
}

# 从 xcresult 摘要里取一个字段(紧凑 JSON,避免引入 jq)
summary_field() {
  local bundle="$1" key="$2" json
  json="$(xcrun xcresulttool get test-results summary --path "$bundle" --compact 2>/dev/null || true)"
  [ -n "$json" ] || return 1
  printf '%s' "$json" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*[^,}]*" | head -1 \
    | sed -E 's/.*:[[:space:]]*//; s/^"//; s/"$//'
}

PASS=0; FAIL=0
while IFS= read -r APP; do
  [ -n "$APP" ] || continue
  note "──────── 应用: $APP ────────"

  if ! grep -q '\.testTarget(' "$REPO_ROOT/apps/$APP/Package.swift"; then
    skip "$APP: 没有 .testTarget(),跳过"
    continue
  fi

  PKG="$(package_name "$APP")"
  [ -n "$PKG" ] || { printf '\033[1;31m[FAIL]\033[0m %s: 读不到 Package.swift 的包名\n' "$APP" >&2; FAIL=$((FAIL+1)); continue; }
  SCHEME="$PKG-Package"

  # SwiftPM 包的聚合 scheme 由 Xcode 自动生成;不存在时给出可操作的提示
  if ! ( cd "$REPO_ROOT/apps/$APP" && xcrun xcodebuild -list -json ) 2>/dev/null | grep -q "\"$SCHEME\""; then
    printf '\033[1;31m[FAIL]\033[0m %s: 没找到 scheme %s(可用: %s)\n' "$APP" "$SCHEME" \
      "$( ( cd "$REPO_ROOT/apps/$APP" && xcrun xcodebuild -list -json ) 2>/dev/null | grep -oE '"[^"]+"' | tr '\n' ' ')" >&2
    FAIL=$((FAIL+1)); continue
  fi

  OUTDIR="$REPO_ROOT/apps/$APP/.build/ios-test"
  mkdir -p "$OUTDIR"
  RB="$OUTDIR/result.xcresult"
  LOG="$OUTDIR/xcodebuild.log"
  rm -rf "$RB"

  ARGS=(test -scheme "$SCHEME" -destination "id=$UDID"
        -derivedDataPath "$OUTDIR/DerivedData" -resultBundlePath "$RB" -quiet)
  [ -n "$FILTER" ] && ARGS+=(-only-testing "$FILTER")
  [ "$COVERAGE" = 1 ] && ARGS+=(-enableCodeCoverage YES)

  note "xcodebuild test($SCHEME)→ iOS Simulator"
  if ( cd "$REPO_ROOT/apps/$APP" && xcrun xcodebuild "${ARGS[@]}" ) >"$LOG" 2>&1; then
    passed="$(summary_field "$RB" passedTests || echo '?')"
    failed="$(summary_field "$RB" failedTests || echo '0')"
    ok "$APP: $passed 通过 / $failed 失败"
    PASS=$((PASS+1))
    if [ "$COVERAGE" = 1 ]; then
      xcrun xccov view --report "$RB" 2>/dev/null | head -20
    fi
  else
    passed="$(summary_field "$RB" passedTests || echo '?')"
    failed="$(summary_field "$RB" failedTests || echo '?')"
    printf '\033[1;31m[FAIL]\033[0m %s: %s 通过 / %s 失败\n' "$APP" "$passed" "$failed" >&2
    echo "--- 日志尾部($LOG)---" >&2
    tail -40 "$LOG" >&2
    echo "--- 详情: xcrun xcresulttool get test-results tests --path $RB" >&2
    FAIL=$((FAIL+1))
  fi
done <<< "$apps"

echo
echo "== 通过 $PASS / 失败 $FAIL =="
[ "$FAIL" -eq 0 ]
