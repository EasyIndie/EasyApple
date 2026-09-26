#!/usr/bin/env bash
# tools/ui-assert.sh — 文本级断言(截图 → OCR → 校验包含/不包含),可直接进 CI
#
# ⚠️ OCR 是「有损」识别:断言串要选**稳定、无歧义**的(如 `arm64`、`模拟器`),
#    别用 OCR 容易看错的(实测 `iPhone 17` 可能被识成 `1Phone 17`)。
#
# 用法:
#   tools/ui-assert.sh --contains "arm64" --contains "模拟器"
#   tools/ui-assert.sh --not-contains "Error"
#   tools/ui-assert.sh --input /tmp/a.png --contains "..."   # 复用已有截图
#   tools/ui-assert.sh --device "iPhone 17" --contains "..."
# 退出码:0 全部通过;1 有断言失败
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

DEVICE="${SIM_DEVICE:-iPhone 17}"
INPUT=""
CONTAINS=()
NOT_CONTAINS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --device) DEVICE="$2"; shift 2 ;;
    --input) INPUT="$2"; shift 2 ;;
    --contains) CONTAINS+=("$2"); shift 2 ;;
    --not-contains) NOT_CONTAINS+=("$2"); shift 2 ;;
    *) die "未知参数: $1" ;;
  esac
done

if [ "$(( ${#CONTAINS[@]} + ${#NOT_CONTAINS[@]} ))" -eq 0 ]; then
  die "至少给一个 --contains 或 --not-contains"
fi

if [ -z "$INPUT" ]; then
  UDID="$(simctl_udid "$DEVICE")"
  mkdir -p "$REPO_ROOT/.tmp"
  INPUT="$REPO_ROOT/.tmp/ui-assert-$(date +%Y%m%d-%H%M%S).png"
  xcrun simctl io "$UDID" screenshot "$INPUT" >/dev/null
  note "截图: $INPUT" >&2
fi
[ -f "$INPUT" ] || die "找不到图片: $INPUT"

BIN="$(ensure_uiscan)"
TEXT="$("$BIN" "$INPUT")" || die "OCR 失败: $INPUT"

FAILED=0
for needle in ${CONTAINS[@]+"${CONTAINS[@]}"}; do
  if printf '%s\n' "$TEXT" | grep -qF -- "$needle"; then
    ok "包含: $needle"
  else
    printf '\033[1;31m[FAIL]\033[0m 缺少: %s\n' "$needle" >&2
    FAILED=1
  fi
done
for needle in ${NOT_CONTAINS[@]+"${NOT_CONTAINS[@]}"}; do
  if printf '%s\n' "$TEXT" | grep -qF -- "$needle"; then
    printf '\033[1;31m[FAIL]\033[0m 不应出现: %s\n' "$needle" >&2
    FAILED=1
  else
    ok "不含: $needle"
  fi
done

if [ "$FAILED" -ne 0 ]; then
  printf '\n--- OCR 实际文本(%s)---\n' "$INPUT" >&2
  printf '%s\n' "$TEXT" >&2
  exit 1
fi
ok "文本断言通过(共 $(( ${#CONTAINS[@]} + ${#NOT_CONTAINS[@]} )) 项)"
