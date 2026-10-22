#!/usr/bin/env bash
# Link EasyApple-managed skills into Codex's shared user-level skills directory.
# Also export skills bundled with the selected local Xcode, as Apple documents.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_SKILLS="$ROOT/.agents/skills"
USER_SKILLS="$HOME/.agents/skills"
mkdir -p "$USER_SKILLS"

link_skill() {
  local name="$1" source="$2" destination="$USER_SKILLS/$1"
  if [[ -L "$destination" ]]; then
    local current
    current="$(readlink "$destination")"
    if [[ "$current" == "$source" ]]; then return 0; fi
    echo "拒绝覆盖已有技能链接: $destination -> $current" >&2
    return 1
  elif [[ -e "$destination" ]]; then
    echo "拒绝覆盖已有技能: $destination；请先自行处理同名技能。" >&2
    return 1
  fi
  ln -s "$source" "$destination"
  echo "已链接: $name"
}

# Community / EasyApple-maintained skill packages follow repository updates.
for source in "$REPO_SKILLS"/*; do
  [[ -d "$source" && -f "$source/SKILL.md" ]] || continue
  link_skill "$(basename "$source")" "$source"
done

# Apple-authored skills remain sourced from the installed Xcode distribution.
if command -v xcrun >/dev/null 2>&1 && xcrun agent skills export --help >/dev/null 2>&1; then
  APPLE_SKILLS="$HOME/Library/Developer/Xcode/CodingAssistant/codex/skills/__xcode"
  mkdir -p "$APPLE_SKILLS"
  xcrun agent skills export --replace-existing --output-dir "$APPLE_SKILLS"
  # 导出的部分技能描述超过 Agent Skills 规范的 1024 字符上限（pi/Claude 会拒绝加载），
  # 这里用仓库维护的短描述覆盖；重新导出后依然生效。
  python3 "$ROOT/tools/apply-skill-description-overrides.py" \
    --overrides "$ROOT/tools/apple-skill-descriptions.json" \
    --skills "$APPLE_SKILLS"
  for source in "$APPLE_SKILLS"/*; do
    [[ -d "$source" && -f "$source/SKILL.md" ]] || continue
    link_skill "$(basename "$source")" "$source"
  done
else
  echo "未检测到支持技能导出的 Xcode；已链接仓库技能，Apple 官方技能可在安装 Xcode 27 后重跑本脚本。" >&2
fi

echo "完成。Codex 重启/新建会话后会发现共享技能目录: $USER_SKILLS"

# 最终校验：共享目录里所有技能的 description 必须在 Agent Skills 规范上限内，
# 否则 pi / Claude 这类按规范校验的客户端会报「技能冲突」并拒绝加载该技能。
if [ -d "$USER_SKILLS" ]; then
  python3 "$ROOT/tools/apply-skill-description-overrides.py" --check-only \
    --overrides "$ROOT/tools/apple-skill-descriptions.json" \
    --skills "$USER_SKILLS" || {
    echo "技能描述校验未通过；把超长技能加进 tools/apple-skill-descriptions.json 后重跑。" >&2
    exit 1
  }
fi
