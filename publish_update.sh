#!/bin/zsh
set -euo pipefail

# 发布新版本：把 DMG 放进 release/，生成 / 更新带 EdDSA 签名的 appcast.xml
#
# 用法：
#   ./publish_update.sh 1.29 "本版更新说明，可多行"
#
# 前置：
#   1. 先在 build.sh 里把 CFBundleShortVersionString / CFBundleVersion 升到新版本，再 ./build.sh
#   2. 下面 REPO 改成你真实的 GitHub 仓库（owner/repo）
#   3. EdDSA 私钥已由 generate_keys 存进本机钥匙串（account 名 ed25519），无需再传

HERE="$(cd "$(dirname "$0")" && pwd)"

VERSION="${1:?用法: $0 <版本号> [更新说明]}"
NOTES="${2:-}"

# ★ 你的 GitHub 仓库
REPO="CyanChung/CyanClone"

RELEASE_DIR="$HERE/release"
mkdir -p "$RELEASE_DIR"

# 1. 复制最新 DMG（generate_appcast 会从归档内 Info.plist 读版本号）
DMG_NAME="Cyan Clone $VERSION.dmg"
cp "$HERE/Cyan-Clone.dmg" "$RELEASE_DIR/$DMG_NAME"

# 2. 更新说明（同名 .md，--embed-release-notes 会直接嵌进 appcast，不用单独上传）
if [ -n "$NOTES" ]; then
  printf '## %s\n%s\n' "$VERSION" "$NOTES" > "$RELEASE_DIR/Cyan Clone $VERSION.md"
else
  printf '## %s\n- （补充本版更新内容）\n' "$VERSION" > "$RELEASE_DIR/Cyan Clone $VERSION.md"
fi

# 3. 生成 / 更新 appcast（EdDSA 私钥从钥匙串读取，公钥已写进 App 的 SUPublicEDKey）
URL_PREFIX="https://github.com/$REPO/releases/download/v$VERSION"
"$HERE/Vendor/bin/generate_appcast" \
  --download-url-prefix "$URL_PREFIX/" \
  --release-notes-url-prefix "$URL_PREFIX/" \
  --embed-release-notes \
  --disable-signing-warning \
  "$RELEASE_DIR"

cat <<EOF

✔ 已生成 $RELEASE_DIR/appcast.xml

发布步骤：
  1. 在 GitHub 建一个 release，tag 填 v$VERSION
  2. 把下面两个文件作为该 release 的附件上传：
       - $DMG_NAME
       - appcast.xml
  3. 确认 App 里的 SUFeedURL（build.sh）指向这个稳定直链：
       https://github.com/$REPO/releases/latest/download/appcast.xml
     （latest/download/appcast.xml 永远指向最新 release 的 appcast，所以 SUFeedURL 不用每次改）

提示：若你换了电脑发版，需先导出私钥（钥匙串 account=ed25519，service=https://sparkle-project.org）：
  security find-generic-password -s "https://sparkle-project.org" -a "ed25519" -w
EOF
