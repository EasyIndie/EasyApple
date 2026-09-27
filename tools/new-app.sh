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
note "接下来:"
note "  1) 改 apps/$NAME/Sources/$NAME/ 与 Sources/${NAME}Core/ —— 模板里还是 EnvDemo 的探测代码"
note "  2) 改 apps/$NAME/ui-assertions.txt —— 换成你自己 UI 的稳定文本断言(OCR)"
note "  3) tools/build.sh $NAME && tools/test.sh $NAME && tools/run-sim.sh --app $NAME"
note "  4) 版本号是全仓库共享的(version.properties,见决策 D8)"
note "  验证无改名残留:grep -rn EnvDemo apps/$NAME"
