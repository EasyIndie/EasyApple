#!/usr/bin/env bash
# tools/ui-dump.sh — UI 验收:截图(截图为先,见决策 D7;文本级用 ui-scan/ui-assert)
#   tools/ui-dump.sh [--device "iPhone 17"] [--out /path.png]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

DEVICE="${SIM_DEVICE:-iPhone 17}"
OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --device) DEVICE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) die "未知参数: $1" ;;
  esac
done

OUT="${OUT:-$REPO_ROOT/.tmp/ui-$(date +%Y%m%d-%H%M%S).png}"
mkdir -p "$(dirname "$OUT")"

UDID="$(xcrun simctl list devices available | grep -F "$DEVICE (" | head -1 \
  | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)"
[ -n "$UDID" ] || die "找不到设备: $DEVICE"

xcrun simctl io "$UDID" screenshot "$OUT" >/dev/null
ok "截图: $OUT"
note "文本验收用 tools/ui-scan.sh(OCR 文本) / tools/ui-assert.sh(断言);路线取舍见 docs/06"
