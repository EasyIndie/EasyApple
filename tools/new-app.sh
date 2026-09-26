#!/usr/bin/env bash
# tools/new-app.sh — 以 EnvDemo 为模板生成 apps/<Name>/
#   tools/new-app.sh <AppName>
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

NAME="${1:-}"
[ -n "$NAME" ] || die "用法: tools/new-app.sh <AppName>"
SRC="$REPO_ROOT/apps/EnvDemo"
DST="$REPO_ROOT/apps/$NAME"
[ -d "$SRC" ] || die "模板不存在: $SRC"
[ -e "$DST" ] && die "目标已存在: $DST"

note "复制模板 EnvDemo → $NAME"
cp -R "$SRC" "$DST"
rm -rf "$DST/.build"

# 替换文件内容里的 EnvDemo → NAME
while IFS= read -r -d '' f; do
  if grep -q 'EnvDemo' "$f" 2>/dev/null; then
    sed -i '' "s/EnvDemo/$NAME/g" "$f"
  fi
done < <(find "$DST" -type f -print0)

# 重命名路径里含 EnvDemo 的文件/目录(自底向上)
while IFS= read -r p; do
  mv "$p" "$(dirname "$p")/$(basename "$p" | sed "s/EnvDemo/$NAME/g")"
done < <(find "$DST" -depth -name '*EnvDemo*')

ok "已生成 apps/$NAME"
note "请检查:Package.swift / Bundle ID / Info.plist 是否都已改名"
