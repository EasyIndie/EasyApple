#!/usr/bin/env bash
# tools/release.sh — 按 Conventional Commits 推导下一个 SemVer
#
#   tools/release.sh --dry-run                  # 只打印建议版本
#   tools/release.sh --check-commits [range]    # 只校验提交信息(默认 上一个tag..HEAD)
#   tools/release.sh                            # 更新 version.properties + CHANGELOG,提交并打 tag
#
# 段位规则:
#   type! 或正文含 BREAKING CHANGE:  → MAJOR(0.x 阶段只升 MINOR,见 docs/05)
#   feat:                            → MINOR
#   fix: / perf: / refactor:         → PATCH
#   其他(docs/chore/ci/...)          → 不发版
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

ACTION="${1:---release}"
[ "$ACTION" = "--release" ] || [ "$ACTION" = "--dry-run" ] || [ "$ACTION" = "--check-commits" ] \
  || die "未知参数: $ACTION(可用 --dry-run / --check-commits [range])"

LAST_TAG="$(git -C "$REPO_ROOT" describe --tags --abbrev=0 2>/dev/null || true)"

if [ "$ACTION" = "--check-commits" ]; then
  RANGE="${2:-${LAST_TAG:+$LAST_TAG..}HEAD}"
  bad=0
  while IFS= read -r subject; do
    [ -n "$subject" ] || continue
    # 合并提交不是人写的,跳过
    case "$subject" in Merge\ *|"Merge pull request"*) continue ;; esac
    if ! printf '%s' "$subject" | grep -qE \
      '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([^)]+\))?!?: .+'; then
      printf '\033[1;31m[bad ]\033[0m %s\n' "$subject" >&2
      bad=1
    fi
  done < <(git -C "$REPO_ROOT" log --format='%s' "$RANGE" 2>/dev/null || true)
  [ "$bad" -eq 0 ] || die "存在不符合 Conventional Commits 的提交($RANGE)"
  ok "提交信息规范($RANGE)"
  exit 0
fi

DRY=0
[ "$ACTION" = "--dry-run" ] && DRY=1

CUR="$(version_from_props)"
MAJOR="${CUR%%.*}"; rest="${CUR#*.}"; MINOR="${rest%%.*}"; PATCH="${rest##*.}"

RANGE="${LAST_TAG:+$LAST_TAG..}HEAD"
SUBJECTS="$(git -C "$REPO_ROOT" log --format='%s' $RANGE 2>/dev/null || true)"
BODIES="$(git -C "$REPO_ROOT" log --format='%B' $RANGE 2>/dev/null || true)"

BREAKING=0
if printf '%s\n' "$SUBJECTS" | grep -qE '^[a-z]+(\([^)]+\))?!:'; then BREAKING=1; fi
if printf '%s\n' "$BODIES" | grep -qE '^BREAKING[ -]CHANGE:'; then BREAKING=1; fi

BUMP="none"
if [ "$BREAKING" = 1 ]; then
  # 0.x 阶段本来就不承诺稳定:直接跳 1.0.0 会误导用户以为已稳定。
  # 真要到 1.0.0,用 --version 1.0.0 明确表达(与 EasyAndroid 的语义保持一致)。
  if [ "$MAJOR" -eq 0 ]; then BUMP="minor"; else BUMP="major"; fi
elif printf '%s\n' "$SUBJECTS" | grep -qE '^feat(\([^)]+\))?:'; then BUMP="minor"
elif printf '%s\n' "$SUBJECTS" | grep -qE '^(fix|perf|refactor)(\([^)]+\))?:'; then BUMP="patch"
fi

case "$BUMP" in
  major) MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR+1)); PATCH=0 ;;
  patch) PATCH=$((PATCH+1)) ;;
  none)  skip "无可发布提交(feat/fix/perf/refactor);当前 $CUR"; exit 0 ;;
esac
NEXT="$MAJOR.$MINOR.$PATCH"

if [ "$BREAKING" = 1 ] && [ "$MAJOR" -eq 0 ] && [ "$BUMP" = "minor" ]; then
  note "检测到 BREAKING,但当前是 0.x:按约定升 MINOR(不是 1.0.0)"
fi
note "当前 $CUR → 建议 $NEXT($BUMP)"

if [ "$DRY" = 1 ]; then echo "$NEXT"; exit 0; fi

sed -i '' "s/^version=.*/version=$NEXT/" "$REPO_ROOT/version.properties"
ok "version.properties → $NEXT"

today="$(date +%Y-%m-%d)"
if grep -q '^## \[Unreleased\]' "$REPO_ROOT/CHANGELOG.md"; then
  awk -v ver="$NEXT" -v day="$today" '
    /^## \[Unreleased\]/ { print; print ""; print "## [" ver "] - " day; next } 1
  ' "$REPO_ROOT/CHANGELOG.md" > "$REPO_ROOT/CHANGELOG.md.tmp"
  mv "$REPO_ROOT/CHANGELOG.md.tmp" "$REPO_ROOT/CHANGELOG.md"
  ok "CHANGELOG.md 已插入 [$NEXT]"
fi

git -C "$REPO_ROOT" add version.properties CHANGELOG.md
git -C "$REPO_ROOT" commit -m "chore(release): $NEXT"
# 必须用附注标签(-a):轻量标签不被 `git push --follow-tags` 推送,release.yml 不会触发
git -C "$REPO_ROOT" tag -a "$NEXT" -m "Release $NEXT"
ok "已提交并打 tag: $NEXT"
note "下一步:git push --follow-tags(触发 release.yml)"
