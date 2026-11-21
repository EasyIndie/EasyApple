#!/usr/bin/env bash
# tools/repo-check.sh — 仓库自检(不依赖 Xcode / 模拟器 / 设备)
#
#   tools/repo-check.sh
#
# 检查项:
#   1. 版本号唯一来源仍是严格 SemVer,且没有第二处 version=
#   2. tools/*.sh 语法(bash -n)
#   3. GitHub Actions:YAML 可解析、runs-on 不写 -latest、action 主版本不倒退、
#      EasyRelease 必须 pin 到具体 tag、选 Xcode 的输入一致
#   4. 文档相对链接全部存在
#   5. 应用目录必备文件(Package.swift / README.md / ui-assertions.txt)
#   6. 决策记录编号与 docs/README 的索引范围一致
#   7. 不把真实内网 IP / token / 私钥写进被跟踪文件
#
# 这是 `verify-all.sh` 的第一步;CI 也直接调它。设计目标是「没有工具链也能跑」。
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

PASS=0; WARN=0; FAIL=0
pass() { printf '  ✅ %s\n' "$1"; PASS=$((PASS+1)); }
warn() { printf '  ⚠️  %s\n' "$1"; WARN=$((WARN+1)); }
fail() { printf '  ❌ %s\n' "$1"; FAIL=$((FAIL+1)); }

echo "== EasyApple 仓库自检 =="

# 交付仓库(handoff-app.sh 导出)不一定带 docs/ 与 workflows:只检查它有的东西。
HANDOFF=0
[ -f "$REPO_ROOT/handoff-manifest.txt" ] && HANDOFF=1

# ---- 1. 版本号 ----
v="$(grep -E '^version=' "$REPO_ROOT/version.properties" 2>/dev/null | head -1 | cut -d= -f2 | tr -d '[:space:]')"
if printf '%s' "$v" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  pass "version.properties 是严格 SemVer($v)"
else
  fail "version.properties 不是严格 SemVer: ${v:-缺失}"
fi
extra_version="$(grep -RIn --exclude-dir=.git --exclude-dir=.build --exclude-dir=.tmp \
  --include='*.sh' --include='*.swift' --include='*.py' --include='*.yml' --include='*.yaml' \
  --include='*.json' --include='*.plist' --include='*.properties' \
  -E '^[[:space:]]*version=' "$REPO_ROOT" 2>/dev/null | grep -v '^.*/version.properties:' || true)"
if [ -z "$extra_version" ]; then
  pass "version= 只出现在 version.properties"
else
  fail "发现第二处 version=:
$extra_version"
fi

# ---- 2. Shell 语法 ----
bad_syntax=0
for f in "$REPO_ROOT"/tools/*.sh; do
  [ -f "$f" ] || continue
  if ! bash -n "$f" 2>/dev/null; then
    fail "语法错误: ${f#"$REPO_ROOT"/}"
    bad_syntax=1
  fi
done
[ "$bad_syntax" -eq 0 ] && pass "tools/*.sh 语法检查通过"

# ---- 3. GitHub Actions ----
# 外部 action → 期望的最低主版本(升级时改这张表,并先读 action.yml)。
min_action_major() {
  case "$1" in
    actions/checkout) echo 4 ;;
    actions/cache) echo 4 ;;
    actions/upload-artifact) echo 4 ;;
    actions/download-artifact) echo 4 ;;
    *) echo "" ;;
  esac
}

wf_dir="$REPO_ROOT/.github/workflows"
if [ ! -d "$wf_dir" ]; then
  [ "$HANDOFF" = 1 ] && pass "交付仓库无 workflows,跳过" || fail "缺少 .github/workflows/"
else
  wf_bad=0
  for wf in "$wf_dir"/*.yml "$wf_dir"/*.yaml; do
    [ -f "$wf" ] || continue
    name="${wf#"$REPO_ROOT"/}"

    # YAML 可解析(没有 ruby 时只警告,不误报失败)
    if command -v ruby >/dev/null 2>&1; then
      if ! ruby -ryaml -e 'YAML.load_file(ARGV[0])' "$wf" >/dev/null 2>&1; then
        fail "$name: YAML 解析失败"; wf_bad=1; continue
      fi
    fi

    # runs-on 必须写具体版本(禁止 -latest)
    if grep -qE '^[[:space:]]*runs-on:[[:space:]]*[^[:space:]]*-latest' "$wf"; then
      fail "$name: runs-on 使用了 -latest(必须显式 pin)"
      wf_bad=1
    fi

    # 外部 action 的版本
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      ref="${line##*uses:}"
      ref="$(printf '%s' "$ref" | awk '{print $1}' | tr -d '\"')"
      case "$ref" in
        ./*|docker://*) continue ;;
      esac
      action="${ref%@*}"
      tag="${ref##*@}"
      [ "$action" != "$ref" ] || { fail "$name: action 没写版本: $ref"; wf_bad=1; continue; }

      # EasyRelease:必须 pin 到具体 apple-vX.Y.Z,且同一 workflow 内一致
      case "$action" in
        EasyIndie/EasyRelease/*)
          printf '%s' "$tag" | grep -qE '^apple-v[0-9]+\.[0-9]+\.[0-9]+$' \
            || { fail "$name: EasyRelease 必须 pin 到 apple-vX.Y.Z(当前 $tag)"; wf_bad=1; }
          continue ;;
      esac

      want="$(min_action_major "$action")"
      if [ -n "$want" ]; then
        got="${tag#v}"; got="${got%%.*}"
        if ! printf '%s' "$got" | grep -qE '^[0-9]+$'; then
          fail "$name: 无法识别 action 版本: $ref"; wf_bad=1
        elif [ "$got" -lt "$want" ]; then
          fail "$name: $action@v$got 低于期望 v$want"; wf_bad=1
        fi
      fi
    done < <(grep -hE '^[[:space:]]*(-[[:space:]]*)?uses:' "$wf" 2>/dev/null || true)

    # 选择 Xcode:必须走统一的 composite action,且输入版本一致
    # (reusable workflow 内部自己选 Xcode;纯打包 job 不需要 Xcode,跳过。)
    if grep -q 'xcode-27' "$wf" && ! grep -q 'uses: EasyIndie/EasyRelease' "$wf"; then
      if grep -q 'select-xcode' "$wf"; then
        ver="$(grep -A2 'select-xcode' "$wf" | sed -n 's/.*version:[[:space:]]*//p' | head -1 | tr -d '\"')"
        if [ -n "$ver" ] && [ -z "${REPO_XCODE_VERSION:-}" ]; then
          REPO_XCODE_VERSION="$ver"
        elif [ -n "$ver" ] && [ "$ver" != "${REPO_XCODE_VERSION:-}" ]; then
          fail "$name: select-xcode 版本($ver)与其他 workflow($REPO_XCODE_VERSION)不一致"
          wf_bad=1
        fi
      else
        warn "$name: 使用 xcode-27 但未走 ./.github/actions/select-xcode"
      fi
    fi
  done

  [ "$wf_bad" -eq 0 ] && pass "GitHub Actions 配置通过(runs-on / action 版本 / Xcode 选择)"
fi

# ---- 4. 文档相对链接 ----
link_bad=0
link_total=0
while IFS= read -r -d '' doc; do
  dir="$(dirname "$doc")"
  while IFS= read -r link; do
    [ -n "$link" ] || continue
    case "$link" in
      http://*|https://*|mailto:*|'#'*|'') continue ;;
    esac
    target="${link%%#*}"
    target="${target%%\?*}"
    [ -n "$target" ] || continue
    link_total=$((link_total+1))
    case "$target" in
      /*) resolved="$target" ;;
      *)  resolved="$dir/$target" ;;
    esac
    if [ ! -e "$resolved" ]; then
      fail "${doc#"$REPO_ROOT"/}: 链接不存在 → $link"
      link_bad=1
    fi
  done < <(grep -oE '\]\([^)]+\)' "$doc" 2>/dev/null | sed 's/^](//; s/)$//' || true)
done < <(find "$REPO_ROOT" -type f -name '*.md' \
  -not -path '*/.git/*' -not -path '*/.build/*' -not -path '*/.tmp/*' \
  -not -path '*/.agents/skills/*' -print0)
[ "$link_bad" -eq 0 ] && pass "文档链接存在($link_total 个相对链接)"

# ---- 5. 应用目录 ----
app_bad=0
app_count=0
for d in "$REPO_ROOT"/apps/*/; do
  [ -f "$d/Package.swift" ] || continue
  app="$(basename "$d")"
  app_count=$((app_count+1))
  [ -f "$d/README.md" ] || warn "apps/$app 缺少 README.md(用 new-app.sh 生成会带)"
  [ -f "$d/ui-assertions.txt" ] || warn "apps/$app 缺少 ui-assertions.txt,verify-all 会跳过文本断言"
done
if [ -f "$REPO_ROOT/template/Package.swift" ] && [ -f "$REPO_ROOT/template/README.md" ]; then
  pass "template/ 存在($app_count 个应用)"
else
  fail "template/ 不完整(需要 Package.swift + README.md)"
  app_bad=1
fi
[ "$app_bad" -eq 0 ] && [ "$app_count" -eq 0 ] && warn "apps/ 下暂无应用"

# ---- 6. 决策编号与索引 ----
decisions="$REPO_ROOT/docs/00-decisions.md"
index="$REPO_ROOT/docs/README.md"
if [ "$HANDOFF" = 1 ] && [ ! -f "$decisions" ]; then
  pass "交付仓库无决策文档,跳过"
elif [ -f "$decisions" ] && [ -f "$index" ]; then
  max_d="$(grep -oE '\*\*D[0-9]+\*\*' "$decisions" | grep -oE '[0-9]+' | sort -n | tail -1)"
  idx="$(grep -oE 'D1[–-]D[0-9]+' "$index" | head -1 | grep -oE '[0-9]+$')"
  if [ -n "$max_d" ] && [ -n "$idx" ] && [ "$idx" != "$max_d" ]; then
    fail "docs/README 的决策范围 D1–D$idx 与 docs/00 的最大编号 D$max_d 不一致"
  else
    pass "决策索引一致(D1–D${idx:-?})"
  fi
else
  fail "缺少 docs/00-decisions.md 或 docs/README.md"
fi

# ---- 7. 敏感信息 ----
# 只查被跟踪文件;真实内网 IP / token / 私钥都不允许入库(AGENTS 硬性规则 6)。
if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  leaks="$(git -C "$REPO_ROOT" grep -nE \
    '192\.168\.[0-9]+\.[0-9]+|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|BEGIN [A-Z ]*PRIVATE KEY' \
    -- . ':!.agents/skills' 2>/dev/null || true)"
  if [ -z "$leaks" ]; then
    pass "无真实内网 IP / token / 私钥"
  else
    fail "发现敏感信息:
$leaks"
  fi
else
  warn "不是 git 仓库,跳过敏感信息检查"
fi

echo
echo "== 通过 $PASS / 警告 $WARN / 失败 $FAIL =="
[ "$FAIL" -eq 0 ]
