#!/usr/bin/env bash
# Refresh MIT-licensed Swift skills from their upstream default branches.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS="$ROOT/.agents/skills"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/easyapple-skills.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

sync_skill() {
  local name="$1" url="$2" source_dir="$3"
  local clone="$TMP/$name" package="$TMP/$name-package" target="$SKILLS/$name"
  git clone --quiet --depth 1 --single-branch "$url" "$clone"
  local rev
  rev="$(git -C "$clone" rev-parse HEAD)"
  [[ -f "$clone/$source_dir/SKILL.md" && -f "$clone/LICENSE" ]] || {
    echo "上游缺少技能说明或许可证: $url ($source_dir)" >&2
    return 1
  }
  mkdir -p "$package"
  cp "$clone/$source_dir/SKILL.md" "$package/SKILL.md"
  cp "$clone/LICENSE" "$package/LICENSE"
  for dir in references agents scripts assets; do
    [[ ! -d "$clone/$source_dir/$dir" ]] || cp -R "$clone/$source_dir/$dir" "$package/$dir"
  done
  python3 - "$package" <<'PY_NORMALIZE'
from pathlib import Path
import sys
root = Path(sys.argv[1])
text_suffixes = {".md", ".yaml", ".yml", ".sh", ".svg"}
for path in root.rglob("*"):
    if not path.is_file() or (path.suffix not in text_suffixes and path.name != "LICENSE"):
        continue
    content = path.read_text()
    normalized = "\n".join(line.rstrip() for line in content.splitlines())
    if content.endswith("\n"):
        normalized += "\n"
    path.write_text(normalized)
PY_NORMALIZE
  mkdir -p "$target"
  rsync -a --delete "$package/" "$target/"
  printf '%s\t%s\t%s\n' "$name" "$url" "$rev" >> "$TMP/lock.tsv"
}

: > "$TMP/lock.tsv"
sync_skill swiftui-pro https://github.com/twostraws/SwiftUI-Agent-Skill.git swiftui-pro
sync_skill swift-concurrency-pro https://github.com/twostraws/Swift-Concurrency-Agent-Skill.git swift-concurrency-pro
python3 - "$TMP/lock.tsv" "$ROOT/.agents/skills-sources.lock.json" <<'PY'
import json
import pathlib
import sys

rows = []
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
    name, url, revision = line.split("\t")
    rows.append({"name": name, "repository": url, "revision": revision, "ref": "upstream-default-branch"})
pathlib.Path(sys.argv[2]).write_text(json.dumps({"skills": rows}, indent=2) + "\n")
PY
printf '已更新社区技能；Apple 原生技能由 tools/install-agent-skills.sh 从本机 Xcode 导出。\n'
