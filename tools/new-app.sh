#!/usr/bin/env bash
# tools/new-app.sh — 从 template/ 生成 apps/<Name>/
#
#   tools/new-app.sh <AppName>                  # 生成到 apps/<AppName>/
#   tools/new-app.sh <AppName> --dest <目录>     # 生成到指定目录(用于模板冒烟)
#   tools/new-app.sh <AppName> --force           # 目标已存在时先删掉(仅 --dest 临时目录建议用)
#
# 模板在仓库根 template/(不在 apps/ 下,不参与构建/发版)。见 docs/10。
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

NAME=""
DEST_ROOT="$REPO_ROOT/apps"
FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dest) DEST_ROOT="${2:?--dest 需要一个目录}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -*) die "未知参数: $1" ;;
    *)
      [ -z "$NAME" ] || die "只能给一个应用名(已收到: $NAME)"
      NAME="$1"; shift ;;
  esac
done

[ -n "$NAME" ] || die "用法: tools/new-app.sh <AppName> [--dest <目录>] [--force]"
# 只允许字母开头 + 字母数字:Swift 模块名不能有连字符/空格,也避免 sed 注入。
printf '%s' "$NAME" | grep -qE '^[A-Za-z][A-Za-z0-9]*$' \
  || die "应用名必须是字母开头的字母数字串(Swift 模块名): $NAME"

SRC="$REPO_ROOT/template"
DST="$DEST_ROOT/$NAME"
[ -f "$SRC/Package.swift" ] || die "模板不存在: $SRC(见 docs/10)"
if [ -e "$DST" ]; then
  if [ "$FORCE" = 1 ]; then
    rm -rf "$DST"
  else
    die "目标已存在: $DST(要覆盖请加 --force)"
  fi
fi

note "复制模板 template → $DST"
mkdir -p "$DEST_ROOT"
cp -R "$SRC" "$DST"
rm -rf "$DST/.build"

# 替换文件内容里的 TemplateApp → NAME
while IFS= read -r -d '' f; do
  if grep -q 'TemplateApp' "$f" 2>/dev/null; then
    sed -i '' "s/TemplateApp/$NAME/g" "$f"
  fi
done < <(find "$DST" -type f -print0)

# 重命名路径里含 TemplateApp 的文件/目录(自底向上)
while IFS= read -r p; do
  mv "$p" "$(dirname "$p")/$(basename "$p" | sed "s/TemplateApp/$NAME/g")"
done < <(find "$DST" -depth -name '*TemplateApp*')

# 机械替换不懂语义:留一处残留就当场失败,别等构建时才报错。
leftover="$(grep -rn 'TemplateApp' "$DST" 2>/dev/null || true)"
[ -z "$leftover" ] || die "生成后仍有 TemplateApp 残留:
$leftover"

ok "已生成 $DST"
note "接下来:"
note "  1) 改 Sources/$NAME/ 与 Sources/${NAME}Core/ —— 模板只有一屏 Hello"
note "  2) 改 ui-assertions.txt —— 换成你自己 UI 的稳定文本断言(OCR)"
note "  3) tools/build.sh $NAME && tools/test.sh $NAME && tools/run-sim.sh --app $NAME"
note "  4) 版本号是全仓库共享的(version.properties,见决策 D8)"
note "  模板冒烟(改过 template/ 后必跑): tools/test-template.sh"
