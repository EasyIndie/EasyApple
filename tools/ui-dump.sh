#!/usr/bin/env bash
# tools/ui-dump.sh — UI 验收:截图(截图为先,见决策 D7;文本级用 ui-scan/ui-assert)
#
# 截图前固定会进画面的随机量(状态栏时间/电量/信号;可选外观与动态字体),
# 截完自动恢复 —— 截图与 OCR 断言因此可复现(见 docs/06 §2.1)。
#
# 用法:
#   tools/ui-dump.sh                                  # 自动挑设备(已启动 > iPhone 17 > 最新)
#   tools/ui-dump.sh --device "iPhone 17" --out /tmp/a.png
#   tools/ui-dump.sh --udid <UDID> --out /tmp/a.png
#   tools/ui-dump.sh --appearance dark                # 深色模式截图
#   tools/ui-dump.sh --content-size accessibility-large   # 大字号截图
#   tools/ui-dump.sh --no-fix-status                  # 不动状态栏(保留当前状态)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

DEVICE_QUERY="${SIM_DEVICE:-}"
OUT=""
FIX_STATUS=1
APPEARANCE=""
CONTENT_SIZE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --device) DEVICE_QUERY="$2"; shift 2 ;;
    --udid) DEVICE_QUERY="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --appearance) APPEARANCE="$2"; shift 2 ;;
    --content-size) CONTENT_SIZE="$2"; shift 2 ;;
    --no-fix-status) FIX_STATUS=0; shift ;;
    *) die "未知参数: $1" ;;
  esac
done

case "$APPEARANCE" in ''|light|dark) ;; *) die "--appearance 只支持 light / dark" ;; esac

OUT="${OUT:-$REPO_ROOT/.tmp/ui-$(date +%Y%m%d-%H%M%S).png}"
mkdir -p "$(dirname "$OUT")"

UDID="$(simctl_resolve_device "$DEVICE_QUERY")"

trap ui_env_restore EXIT
ui_env_lock "$UDID" "$FIX_STATUS" "$APPEARANCE" "$CONTENT_SIZE"

xcrun simctl io "$UDID" screenshot "$OUT" >/dev/null

ui_env_restore

ok "截图: $OUT"
note "文本验收用 tools/ui-scan.sh(OCR 文本) / tools/ui-assert.sh(断言);路线取舍见 docs/06"
