#!/bin/zsh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/Cyan Clone.app"
BIN="$APP/Contents/MacOS/CyanClone"

echo "› 编译 Swift 源码…"
TMPBIN="$(mktemp -d)/CyanClone"
swiftc \
  -O \
  -swift-version 5 \
  -target arm64-apple-macos14.0 \
  -F "$HERE/Vendor" \
  -framework Sparkle \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  -o "$TMPBIN" \
  "$HERE"/Sources/*.swift

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$TMPBIN" "$BIN"
cp -R "$HERE/Vendor/Sparkle.framework" "$APP/Contents/Frameworks/"

echo "› 写入 Info.plist…"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Cyan Clone</string>
    <key>CFBundleDisplayName</key>
    <string>Cyan Clone</string>
    <key>CFBundleExecutable</key>
    <string>CyanClone</string>
    <key>CFBundleIdentifier</key>
    <string>com.cyan.cyanclone</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.30</string>
    <key>CFBundleVersion</key>
    <string>30</string>
    <key>SUFeedURL</key>
    <string>https://github.com/CyanChung/CyanClone/releases/latest/download/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>so6xqs4eUp11SDiJ9Pb3nnHxbrJafG973Ls9NXNgS7I=</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUAutomaticallyUpdate</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>zh-Hans</string>
        <string>zh_CN</string>
        <string>en</string>
    </array>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHumanReadableCopyright</key>
    <string>本地索引，数据不出本机</string>
    <key>NSRemovableVolumesUsageDescription</key>
    <string>需要读取移动硬盘的目录层级与文件名，以便建立可离线浏览的目录索引。不会复制或读取文件内容。</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>读取桌面文件夹的目录结构以建立索引。</string>
    <key>NSDocumentsFolderUsageDescription</key>
    <string>读取文稿文件夹的目录结构以建立索引。</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>读取下载文件夹的目录结构以建立索引。</string>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.cyan.cyanclone.library</string>
            <key>UTTypeDescription</key>
            <string>Cyan Clone 数据文件</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.data</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>cyan</string>
                </array>
                <key>public.mime-type</key>
                <string>application/x-cyan</string>
            </dict>
        </dict>
    </array>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Cyan Clone 数据文件</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Owner</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>com.cyan.cyanclone.library</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

if [ -f "$HERE/AppIcon.icns" ]; then
  cp "$HERE/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" >/dev/null
fi

if [ -d "$HERE/Resources" ]; then
  cp -R "$HERE/Resources/." "$APP/Contents/Resources/"
fi

# 声明中文环境：保存/打开面板这类系统 UI 才会跟着说中文
mkdir -p "$APP/Contents/Resources/zh-Hans.lproj" "$APP/Contents/Resources/zh_CN.lproj"
printf '"CFBundleName" = "Cyan Clone";\n' > "$APP/Contents/Resources/zh-Hans.lproj/InfoPlist.strings"
printf '"CFBundleName" = "Cyan Clone";\n' > "$APP/Contents/Resources/zh_CN.lproj/InfoPlist.strings"
: > "$APP/Contents/Resources/zh-Hans.lproj/Localizable.strings"
: > "$APP/Contents/Resources/zh_CN.lproj/Localizable.strings"

echo "› 签名 Sparkle 组件与 App…"
FW="$APP/Contents/Frameworks/Sparkle.framework"
B="$FW/Versions/B"
SIGN() { codesign --force --sign - "$1" >/dev/null 2>&1 || true; }
# Sparkle 的嵌套 XPC / Autoupdate / Updater.app 必须由内向外单独签，
# --deep 一把梭会导致 XPC 服务签名无效、更新安装失败。
SIGN "$B/XPCServices/Downloader.xpc"
SIGN "$B/XPCServices/Installer.xpc"
SIGN "$B/Autoupdate"
SIGN "$B/Updater.app"
SIGN "$FW"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "✔ 已生成: $APP"

echo "› 打包 ZIP…"
ZIP="$HERE/Cyan-Clone.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
echo "✔ 已生成: $ZIP"

echo "› 打包 DMG…"
DMG_TMP="$(mktemp -d)"
cp -R "$APP" "$DMG_TMP/"
ln -s /Applications "$DMG_TMP/Applications"
DMG="$HERE/Cyan-Clone.dmg"
rm -f "$DMG"
hdiutil create -volname "Cyan Clone" -srcfolder "$DMG_TMP" -ov -format UDZO -quiet "$DMG"
rm -rf "$DMG_TMP"

echo "✔ 已生成: $DMG"
