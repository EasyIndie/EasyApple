#!/usr/bin/env bash
# tools/bootstrap.sh — 一次性装机引导(幂等;不代替人做 sudo / Apple ID 登录)
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

XCODES_VERSION="2.1.0"
XCODES_URL="https://github.com/XcodesOrg/xcodes/releases/download/${XCODES_VERSION}/xcodes.zip"

echo "== EasyApple bootstrap =="

# 1) xcodes(直下 release 二进制;brew 源码构建在沙箱里会被 getcwd 拦)
if command -v xcodes >/dev/null 2>&1; then
  ok "xcodes 已装: $(xcodes version 2>/dev/null)"
else
  note "安装 xcodes ${XCODES_VERSION}(直下 release 二进制)"
  TMP="$(mktemp -d)"
  curl -fsSL -o "$TMP/xcodes.zip" "$XCODES_URL" || die "下载 xcodes 失败"
  unzip -oq "$TMP/xcodes.zip" -d "$TMP" || die "解压 xcodes 失败"
  install -m 0755 "$TMP/xcodes" /opt/homebrew/bin/xcodes || die "安装 xcodes 失败"
  rm -rf "$TMP"
  ok "xcodes → /opt/homebrew/bin/xcodes"
fi

# 2) Xcode 27(需要人工 Apple ID + 2FA + sudo)
if xcrun xcodebuild -version 2>/dev/null | grep -q 'Xcode 27'; then
  ok "Xcode 27 已就绪"
else
  warn "Xcode 27 未就绪。请手动执行(需 Apple ID + 2FA + sudo):"
  cat <<'EOS'
      xcodes install 27.0
      sudo xcodebuild -license accept
      xcodes select 27.0
EOS
fi

# 3) iOS 模拟器 runtime(可能需登录 + sudo)
if xcrun simctl list runtimes 2>/dev/null | grep -q '^iOS 27'; then
  ok "iOS 27 runtime 已就绪"
else
  warn "iOS 27 runtime 未就绪。请手动执行:"
  echo "      xcodes runtimes install \"iOS 27.0\""
fi

# 4) 自检
echo
note "运行 doctor…"
bash "$REPO_ROOT/tools/doctor.sh" || true
