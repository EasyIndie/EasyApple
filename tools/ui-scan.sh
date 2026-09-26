#!/usr/bin/env bash
# tools/ui-scan.sh — 文本级验收(截图 → 原生 OCR → 文本)
#
# 原理与取舍见 docs/06-ui-acceptance.md:用 Apple Vision 框架 OCR 截图,
# 免授权、可无头 + CI。是「文本验收」,不是无障碍树。
#
# 用法:
#   tools/ui-scan.sh                       # 对 booted 设备截图并 OCR
#   tools/ui-scan.sh --device "iPhone 17"
#   tools/ui-scan.sh --input /tmp/a.png    # 直接 OCR 已有截图(不重新截图)
#   tools/ui-scan.sh --json                # JSON(含置信度与归一化坐标)
#   tools/ui-scan.sh --fast                # 更快,中文略糙(默认 accurate)
#   tools/ui-scan.sh --min-confidence 0.5
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

DEVICE="${SIM_DEVICE:-iPhone 17}"
INPUT=""
EXTRA=()

while [ $# -gt 0 ]; do
  case "$1" in
    --device) DEVICE="$2"; shift 2 ;;
    --input) INPUT="$2"; shift 2 ;;
    --json) EXTRA+=(--json); shift ;;
    --fast) EXTRA+=(--fast); shift ;;
    --min-confidence) EXTRA+=(--min-confidence "$2"); shift 2 ;;
    *) die "未知参数: $1" ;;
  esac
done

if [ -z "$INPUT" ]; then
  UDID="$(simctl_udid "$DEVICE")"
  mkdir -p "$REPO_ROOT/.tmp"
  INPUT="$REPO_ROOT/.tmp/ui-scan-$(date +%Y%m%d-%H%M%S).png"
  xcrun simctl io "$UDID" screenshot "$INPUT" >/dev/null
  note "截图: $INPUT" >&2
fi
[ -f "$INPUT" ] || die "找不到图片: $INPUT"

BIN="$(ensure_uiscan)"
exec "$BIN" "$INPUT" "${EXTRA[@]+"${EXTRA[@]}"}"
