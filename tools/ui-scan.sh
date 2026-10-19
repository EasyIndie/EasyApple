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
#   tools/ui-scan.sh --appearance dark     # 深色模式;--content-size <档位> 大字号
#   tools/ui-scan.sh --no-fix-status       # 不固定状态栏(默认固定为 09:41/满电/满格)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

DEVICE="${SIM_DEVICE:-iPhone 17}"
INPUT=""
FIX_STATUS=1
APPEARANCE=""
CONTENT_SIZE=""
EXTRA=()

while [ $# -gt 0 ]; do
  case "$1" in
    --device) DEVICE="$2"; shift 2 ;;
    --input) INPUT="$2"; shift 2 ;;
    --appearance) APPEARANCE="$2"; shift 2 ;;
    --content-size) CONTENT_SIZE="$2"; shift 2 ;;
    --no-fix-status) FIX_STATUS=0; shift ;;
    --json) EXTRA+=(--json); shift ;;
    --fast) EXTRA+=(--fast); shift ;;
    --min-confidence) EXTRA+=(--min-confidence "$2"); shift 2 ;;
    *) die "未知参数: $1" ;;
  esac
done

case "$APPEARANCE" in ''|light|dark) ;; *) die "--appearance 只支持 light / dark" ;; esac

if [ -z "$INPUT" ]; then
  UDID="$(simctl_udid "$DEVICE")"
  mkdir -p "$REPO_ROOT/.tmp"
  INPUT="$REPO_ROOT/.tmp/ui-scan-$(date +%Y%m%d-%H%M%S).png"
  trap ui_env_restore EXIT
  ui_env_lock "$UDID" "$FIX_STATUS" "$APPEARANCE" "$CONTENT_SIZE"
  xcrun simctl io "$UDID" screenshot "$INPUT" >/dev/null
  ui_env_restore          # exec 会替掉当前 shell,trap 不会跑,所以先恢复
  trap - EXIT
  note "截图: $INPUT" >&2
fi
[ -f "$INPUT" ] || die "找不到图片: $INPUT"

BIN="$(ensure_uiscan)"
[ -x "$BIN" ] || die "uiscan 不可用(编译失败?)"
exec "$BIN" "$INPUT" "${EXTRA[@]+"${EXTRA[@]}"}"
