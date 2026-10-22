#!/usr/bin/env python3
"""把 Apple 导出技能里超长的 description 换成仓库维护的短描述。

为什么需要：
    Agent Skills 规范规定 `description` 最多 1024 字符，pi / Claude 等按规范校验的
    客户端会拒绝加载超限技能（日志里表现为「技能冲突 / description exceeds 1024」）。
    Xcode 导出的部分 Apple 技能（如 `app-intents-*`）超出该上限，而
    `xcrun agent skills export --replace-existing` 每次都会把长描述写回来。

用法：
    # 导出后按覆盖表改写，并检查是否还有超限技能（有则退出码 1）
    tools/apply-skill-description-overrides.py \
        --overrides tools/apple-skill-descriptions.json \
        --skills "$HOME/Library/Developer/Xcode/CodingAssistant/codex/skills/__xcode"

    # 只检查不改写（doctor / CI 用）
    tools/apply-skill-description-overrides.py --check-only \
        --overrides tools/apple-skill-descriptions.json \
        --skills "$HOME/.agents/skills"

只依赖 Python 标准库；覆盖表里以 `_` 开头的键视为注释。
"""

from __future__ import annotations

import argparse
import json
import os
import re
import stat
import sys
from pathlib import Path

MAX_DESCRIPTION_LENGTH = 1024
FRONTMATTER = re.compile(r"^---\n(.*?)\n---\n", re.S)


def parse_description(frontmatter: str) -> str | None:
    """取 frontmatter 里的 description（支持单行引号与 `>`/`|` 块标量）。"""
    lines = frontmatter.splitlines()
    for index, line in enumerate(lines):
        if not line.startswith("description:"):
            continue
        value = line[len("description:"):].strip()
        if value[:1] in (">", "|"):
            block: list[str] = []
            for follow in lines[index + 1:]:
                if follow and not follow.startswith((" ", "\t")):
                    break
                block.append(follow.strip())
            return " ".join(part for part in block if part)
        if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
            value = value[1:-1]
        return value
    return None


def set_description(path: Path, description: str) -> None:
    """替换 SKILL.md 的 description，保留其余 frontmatter 与正文；保留原有文件权限。"""
    mode = path.stat().st_mode
    os.chmod(path, mode | stat.S_IWUSR)
    try:
        content = path.read_text(encoding="utf-8")
        match = FRONTMATTER.match(content)
        if not match:
            raise SystemExit(f"缺少 YAML frontmatter：{path}")
        lines = []
        replaced = False
        for line in match.group(1).splitlines():
            if line.startswith("description:"):
                lines.append("description: " + json.dumps(description, ensure_ascii=False))
                replaced = True
            else:
                lines.append(line)
        if not replaced:
            raise SystemExit(f"frontmatter 里没有 description：{path}")
        path.write_text(
            content[: match.start(1)] + "\n".join(lines) + content[match.end(1):],
            encoding="utf-8",
        )
    finally:
        os.chmod(path, mode)


def skill_description(path: Path) -> str | None:
    try:
        content = path.read_text(encoding="utf-8")
    except OSError:
        return None
    match = FRONTMATTER.match(content)
    return parse_description(match.group(1)) if match else None


def main() -> int:
    parser = argparse.ArgumentParser(description="覆盖 / 校验技能 description 长度")
    parser.add_argument("--overrides", required=True, help="覆盖表 JSON（键 = 技能目录名）")
    parser.add_argument("--skills", required=True, help="技能目录（每个子目录一个 SKILL.md）")
    parser.add_argument("--check-only", action="store_true", help="只检查，不改写")
    args = parser.parse_args()

    skills = Path(args.skills).expanduser()
    if not skills.is_dir():
        print(f"技能目录不存在：{skills}", file=sys.stderr)
        return 1

    overrides = json.loads(Path(args.overrides).read_text(encoding="utf-8"))
    overrides = {k: v for k, v in overrides.items() if not k.startswith("_")}

    if not args.check_only:
        for name, description in overrides.items():
            if len(description) > MAX_DESCRIPTION_LENGTH:
                print(f"覆盖表里 {name} 的描述超长（{len(description)} > {MAX_DESCRIPTION_LENGTH}）", file=sys.stderr)
                return 1
            path = skills / name / "SKILL.md"
            if not path.is_file():
                print(f"[skip] {name}：目录里没有该技能（Xcode 未导出？）", file=sys.stderr)
                continue
            if skill_description(path) == description:
                print(f"[ ok ] {name}：已是最短描述（{len(description)} 字符）")
                continue
            set_description(path, description)
            print(f"[fix ] {name}：description 改为 {len(description)} 字符")

    oversized = []
    for path in sorted(skills.glob("*/SKILL.md")):
        description = skill_description(path)
        if description is None:
            continue
        if len(description) > MAX_DESCRIPTION_LENGTH:
            oversized.append((path.parent.name, len(description)))

    if oversized:
        print("以下技能的 description 超过 Agent Skills 规范的 1024 字符，pi / Claude 会拒绝加载：", file=sys.stderr)
        for name, length in oversized:
            print(f"  - {name}（{length} 字符）", file=sys.stderr)
        print("把它加进 tools/apple-skill-descriptions.json 后重跑本脚本。", file=sys.stderr)
        return 1

    print(f"[ ok ] 全部技能 description 均在 {MAX_DESCRIPTION_LENGTH} 字符以内")
    return 0


if __name__ == "__main__":
    sys.exit(main())
