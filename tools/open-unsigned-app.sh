#!/usr/bin/env bash
# open-unsigned-app.sh — 打开「未真实签名(ad-hoc)」的 .app
#
# 背景:Github Release 里的产物若**没有用 Developer ID 签名、也未公证**,
#   Gatekeeper 会拦下,双击时提示「无法打开,因为 Apple 无法检查其是否包含恶意软件」。
#   原因不是 app 有问题,而是它**没有签名背书**。
#
# 本脚本做两件事:
#   ① 去掉下载时由浏览器/系统加上的隔离属性 xattr(com.apple.quarantine);
#   ② 用 `open` 启动它。
#
# ⚠️ 仅在你**信任**该产物来源(你自己构建 / 本仓库 CI 产出)时使用。
# ⚠️ 已用 Developer ID 签名并入证的正式产物**不需要**本脚本,双击即可。
#
# 用法:
#   bash open-unsigned-app.sh [路径/to/Xxx.app]
#   (不给参数时,自动取本脚本同目录下的第一个 .app)
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP="${1:-}"
if [ -z "$APP" ]; then
  shopt -s nullglob
  candidates=("$DIR"/*.app)
  if [ "${#candidates[@]}" -eq 0 ]; then
    echo "错误:同目录下没有 .app。请把 app 路径作为参数传入。" >&2
    exit 1
  fi
  APP="${candidates[0]}"
fi

if [ ! -d "$APP" ]; then
  echo "错误:找不到 app:$APP" >&2
  exit 1
fi
echo "目标:$APP"

# 判断签名类型:ad-hoc(未真实签名)会带 Signature=adhoc / TeamIdentifier=not set
info="$(codesign -dv --verbose=4 "$APP" 2>&1 || true)"
if printf '%s' "$info" | grep -qE 'Signature=adhoc|TeamIdentifier=not set'; then
  echo "签名:ad-hoc(未真实签名)→ 需要去隔离"
else
  echo "签名:看起来已真实签名;若仍被 Gatekeeper 拦,继续去隔离也无妨"
fi

# 去掉下载隔离属性(不存在时也无害)
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
echo "已去除下载隔离属性(如存在)"

echo "启动…"
open "$APP"
echo "完成。若系统仍弹窗拦截,请到「系统设置 → 隐私与安全性」选择「仍要打开」。"
