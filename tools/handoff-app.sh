#!/usr/bin/env bash
# tools/handoff-app.sh — 把 apps/<App> 交付成一个自包含的小仓库
#
#   tools/handoff-app.sh EnvDemo --to ../EnvDemo            # 干跑,只检查
#   tools/handoff-app.sh EnvDemo --to ../EnvDemo --write    # 真正导出
#   tools/handoff-app.sh EnvDemo --to ../EnvDemo --write --force
#
# 为什么导出整套工具链:工具脚本按 REPO_ROOT/apps/<App> 找应用。只把应用源码甩出去,
# 对方拿到的是「构建不了的壳」。所以这里导出 apps/<App> + 运行所需 tools/ + template/
# + version.properties,目标目录本身就是一个可构建、可验收的小仓库。
#
# 交付物:
#   apps/<App>/                 应用源码(不含 .build)
#   tools/                      构建 / 测试 / 模拟器 / OCR / 发版脚本
#   template/                   新建应用模板
#   version.properties          版本唯一来源
#   README.md                   构建与验收说明(已存在则保留)
#   handoff-manifest.txt        来源 commit / 版本 / 文件 sha256
#
# 约定见 docs/10-app-lifecycle-and-handoff.md。
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

APP=""
DEST=""
WRITE=0
FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --to) DEST="${2:?--to 需要一个目录}"; shift 2 ;;
    --write) WRITE=1; shift ;;
    --force) FORCE=1; shift ;;
    -*) die "未知参数: $1" ;;
    *)
      [ -z "$APP" ] || die "只能指定一个应用"
      APP="$1"; shift ;;
  esac
done

[ -n "$APP" ] || die "用法: tools/handoff-app.sh <AppName> --to <目录> [--write] [--force]"
[ -n "$DEST" ] || die "缺少 --to <目录>"
APP_DIR="$REPO_ROOT/apps/$APP"
[ -f "$APP_DIR/Package.swift" ] || die "找不到应用: apps/$APP"

# 目标目录不能是仓库自身、apps/ 内部或根目录
mkdir -p "$(dirname "$DEST")"
DEST_ABS="$(cd "$(dirname "$DEST")" && pwd)/$(basename "$DEST")"
case "$DEST_ABS" in
  /|"$REPO_ROOT"|"$REPO_ROOT"/apps|"$REPO_ROOT"/apps/*)
    die "拒绝导出到 $DEST_ABS(不能是仓库根 / apps/)" ;;
esac

echo "== EasyApple handoff: $APP =="
echo "目标: $DEST_ABS"
echo

FAIL=0; WARN=0
chk_ok()   { printf '  ✅ %s\n' "$1"; }
chk_warn() { printf '  ⚠️  %s\n' "$1"; WARN=$((WARN+1)); }
chk_bad()  { printf '  ❌ %s\n' "$1"; FAIL=$((FAIL+1)); }

# ---- 1. 应用自身 ----
[ -f "$APP_DIR/README.md" ] && chk_ok "apps/$APP/README.md" \
  || chk_bad "缺少 apps/$APP/README.md(说清怎么构建/运行/验收)"
[ -f "$APP_DIR/ui-assertions.txt" ] && chk_ok "ui-assertions.txt" \
  || chk_warn "缺少 apps/$APP/ui-assertions.txt,交付后无法做文本断言"

residue="$(grep -rn 'TemplateApp' "$APP_DIR" --exclude-dir=.build 2>/dev/null || true)"
[ -z "$residue" ] && chk_ok "无 TemplateApp 残留" \
  || chk_bad "应用里还有 TemplateApp 残留:
$residue"

abs_paths="$(grep -rn '/Users/' "$APP_DIR" --exclude-dir=.build --exclude-dir=.git 2>/dev/null || true)"
[ -z "$abs_paths" ] && chk_ok "无绝对家目录路径" \
  || chk_warn "源码里有绝对路径(换机器会坏):
$abs_paths"

secrets="$(find "$APP_DIR" -name '*.p12' -o -name '*.mobileprovision' 2>/dev/null || true)"
[ -z "$secrets" ] && chk_ok "无签名凭据" \
  || chk_bad "应用目录里有签名凭据:
$secrets"

big="$(find "$APP_DIR" -type f -not -path '*/.build/*' -size +5M 2>/dev/null || true)"
[ -z "$big" ] && chk_ok "无 >5MB 的源文件" \
  || chk_warn "有较大的文件(确认是否该入库):
$big"

# ---- 2. 版本与工具链 ----
if bash "$REPO_ROOT/tools/sync-version.sh" --check >/dev/null 2>&1; then
  chk_ok "版本校验(sync-version --check)"
else
  chk_bad "版本校验失败;先跑 tools/sync-version.sh --check"
fi

VERSION="$(version_from_props)"
BUNDLE_VERSION="$(bundle_version_from_props)"
BUNDLE_ID="com.easyapple.$(printf '%s' "$APP" | tr '[:upper:]' '[:lower:]')"
COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
TAG="$(git -C "$REPO_ROOT" describe --tags --abbrev=0 2>/dev/null || echo none)"
XCODE="$(xcrun xcodebuild -version 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')"
SWIFT="$(xcrun swift --version 2>/dev/null | head -1)"

echo
if [ "$FAIL" -ne 0 ]; then
  echo "== 预检失败 $FAIL 项 / 警告 $WARN 项;未写入任何文件 =="
  exit 1
fi

# ---- 3. 计划 ----
echo "== 导出内容 =="
printf '  · %s\n' \
  "apps/$APP/" \
  "tools/(构建/测试/模拟器/OCR/发版脚本)" \
  "template/" \
  "version.properties" \
  "README.md" \
  "handoff-manifest.txt"

if [ "$WRITE" != 1 ]; then
  echo
  echo "== 干跑通过(警告 $WARN 项);加 --write 真正导出 =="
  exit 0
fi

if [ -e "$DEST_ABS" ]; then
  [ "$FORCE" = 1 ] || die "目标已存在: $DEST_ABS(要覆盖加 --force)"
  rm -rf "$DEST_ABS"
fi
mkdir -p "$DEST_ABS/apps"

# ---- 4. 复制 ----
note "复制应用"
cp -R "$APP_DIR" "$DEST_ABS/apps/$APP"
rm -rf "$DEST_ABS/apps/$APP/.build"
find "$DEST_ABS/apps/$APP" -name '.DS_Store' -delete 2>/dev/null || true

note "复制工具链"
mkdir -p "$DEST_ABS/tools"
TOOL_FILES=(
  _common.sh build.sh test.sh test-ios.sh bundle.sh run-sim.sh sim.sh
  ui-dump.sh ui-scan.sh ui-assert.sh uiscan.swift
  verify-all.sh repo-check.sh sync-version.sh new-app.sh test-template.sh
  release.sh doctor.sh
)
for f in "${TOOL_FILES[@]}"; do
  [ -f "$REPO_ROOT/tools/$f" ] || die "工具链缺文件: tools/$f"
  cp "$REPO_ROOT/tools/$f" "$DEST_ABS/tools/$f"
done
cp -R "$REPO_ROOT/template" "$DEST_ABS/template"
cp "$REPO_ROOT/version.properties" "$DEST_ABS/version.properties"

# 目标仓库的 CHANGELOG 从交付版本重新开始,不继承 EasyApple 的历史
cat > "$DEST_ABS/CHANGELOG.md" <<EOF
# Changelog

本项目的所有显著变更都记录在此。

版本号唯一来源是 \`version.properties\`。发版:\`tools/release.sh\`。

## [$VERSION] - 交付自 EasyApple

- 从 EasyApple \`$COMMIT\` 交付 \`apps/$APP\`。
EOF

# ---- 5. README(不覆盖已有) ----
if [ ! -f "$DEST_ABS/README.md" ]; then
  cat > "$DEST_ABS/README.md" <<EOF
# $APP

从 [EasyApple](https://github.com/EasyIndie/EasyApple) \`$COMMIT\` 交付的应用仓库。
自带构建 / 测试 / 模拟器 / OCR 验收 / 发版脚本,不依赖 EasyApple 仓库本体。

## 环境

- macOS(arm64)+ 完整 Xcode(**不要求打开 GUI**)
- 当前交付工具链:$XCODE / $SWIFT
- 首次体检:\`tools/doctor.sh\`

## 构建 / 运行 / 验收

\`\`\`bash
tools/build.sh $APP
tools/test.sh $APP
tools/test-ios.sh --app $APP
tools/run-sim.sh --app $APP
tools/ui-assert.sh --app $APP
\`\`\`

一键端到端:\`tools/verify-all.sh\`。

## 新建应用

\`\`\`bash
tools/new-app.sh <Name>
tools/test-template.sh
\`\`\`

## 发版

\`\`\`bash
tools/release.sh --dry-run
tools/release.sh
git push --follow-tags
\`\`\`

发版流水线(EasyRelease 签名 / 公证)不在本仓库内;需要时从 EasyApple 复制
\`.github/workflows/\` 或直接复用 EasyIndie/EasyRelease。

## 来源

见 \`handoff-manifest.txt\`(commit / 版本 / 每个源文件的 sha256)。
EOF
fi

# ---- 6. manifest ----
{
  echo "# EasyApple handoff manifest"
  echo "# 校验: shasum -a 256 -c handoff-manifest.txt(只含 apps/ 下的源文件)"
  echo "app=$APP"
  echo "bundle_id=$BUNDLE_ID"
  echo "version=$VERSION"
  echo "bundle_version=$BUNDLE_VERSION"
  echo "platforms=macOS 14+, iOS 17+"
  echo "source_repo=https://github.com/EasyIndie/EasyApple.git"
  echo "source_commit=$COMMIT"
  echo "source_tag=$TAG"
  echo "exported_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "toolchain=$XCODE / $SWIFT"
  echo
  ( cd "$DEST_ABS" && find "apps/$APP" -type f | LC_ALL=C sort | while IFS= read -r f; do
      shasum -a 256 "$f"
    done )
} > "$DEST_ABS/handoff-manifest.txt"

# manifest 头部的注释行会让 `shasum -c` 报格式错;校验时用 --ignore-missing 也不行。
# 所以在末尾追加一个纯校验文件,保证 `shasum -a 256 -c` 直接可用。
grep -E '^[0-9a-f]{64}  ' "$DEST_ABS/handoff-manifest.txt" > "$DEST_ABS/handoff-manifest.sha256" || true

ok "已交付: $DEST_ABS"
note "目标仓库自检: cd \"$DEST_ABS\" && tools/verify-all.sh"
note "manifest: handoff-manifest.txt / handoff-manifest.sha256"
