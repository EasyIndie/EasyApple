#!/usr/bin/env bash
# tools/release.sh — 按 Conventional Commits 推导下一个 SemVer
#
#   tools/release.sh --dry-run    # 只打印建议版本
#   tools/release.sh              # 更新 version.properties + CHANGELOG,提交并打 tag
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

CUR="$(version_from_props)"
MAJOR="${CUR%%.*}"; rest="${CUR#*.}"; MINOR="${rest%%.*}"; PATCH="${rest##*.}"

LAST_TAG="$(git -C "$REPO_ROOT" describe --tags --abbrev=0 2>/dev/null || true)"
RANGE="${LAST_TAG:+$LAST_TAG..}HEAD"
MSGS="$(git -C "$REPO_ROOT" log --format='%s' $RANGE 2>/dev/null || true)"

BUMP="none"
if printf '%s\n' "$MSGS" | grep -qE '^[a-z]+(\(.+\))?!:'; then BUMP="major"
elif printf '%s\n' "$MSGS" | grep -qE '^feat(\(.+\))?:'; then BUMP="minor"
elif printf '%s\n' "$MSGS" | grep -qE '^(fix|perf|refactor)(\(.+\))?:'; then BUMP="patch"
fi

case "$BUMP" in
  major) MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR+1)); PATCH=0 ;;
  patch) PATCH=$((PATCH+1)) ;;
  none)  skip "无可发布提交(feat/fix/...);当前 $CUR"; exit 0 ;;
esac
NEXT="$MAJOR.$MINOR.$PATCH"
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
