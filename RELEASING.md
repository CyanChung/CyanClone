# Cyan Clone · 版本更新（Sparkle）发布指南

App 已集成 [Sparkle](https://sparkle-project.org) 自动更新：关于面板里的「检查更新」会从
GitHub Releases 上的 `appcast.xml` 检查新版本，有新版就自动下载并安装。

## 一、机制一图流

```
发版者                        GitHub Releases                  用户
─────────────────────────────────────────────────────────────────────
./build.sh                    ① 上传 DMG + appcast.xml
./publish_update.sh ────────► ② latest/download/appcast.xml
                                   ▲
                                   │ SUFeedURL 指向这里
                                   │
                              App「检查更新」→ 读 appcast → 发现新版 → 下载 DMG → 安装
```

- **公钥**（`SUPublicEDKey`）已经写进 App 的 `Info.plist`，用来校验 appcast 的 EdDSA 签名。
- **私钥**由 `generate_keys` 生成并存进**本机钥匙串**（account 名 `ed25519`），
  `generate_appcast` 签名时会自动读取，绝不打包进 App。

## 二、首次配置（已完成）

- `SUFeedURL` 已指向 `https://github.com/CyanChung/CyanClone/releases/latest/download/appcast.xml`；
- `publish_update.sh` 的 `REPO` 已设为 `CyanChung/CyanClone`；
- 公钥已写进 App 的 `SUPublicEDKey`，私钥在本机钥匙串。
- 若 fork 后自行发布，改 `build.sh` 的 `SUFeedURL` 和 `publish_update.sh` 的 `REPO` 即可。

## 三、每次发新版

1. 改 `build.sh` 里的版本号（两处）：
   - `CFBundleShortVersionString`：`1.28` → `1.29`
   - `CFBundleVersion`：`28` → `29`（Sparkle 用这个数字比较新旧）
2. `./build.sh` 重新编译打包 DMG。
3. `./publish_update.sh 1.29 "本版更新说明"` —— 生成 `release/appcast.xml`（已签名）。
4. 在 GitHub 建 release，tag 填 `v1.29`，上传这两个文件：
   - `Cyan Clone 1.29.dmg`
   - `appcast.xml`
5. 完成。`latest/download/appcast.xml` 自动指向本次，已装用户下次「检查更新」就能收到。

## 四、密钥说明

- 公钥：`so6xqs4eUp11SDiJ9Pb3nnHxbrJafG973Ls9NXNgS7I=`（在 `build.sh` 的 `SUPublicEDKey`）。
- 私钥：本机钥匙串，account 名 `ed25519`、service `https://sparkle-project.org`。换电脑发版前导出：
  ```sh
  security find-generic-password -s "https://sparkle-project.org" -a "ed25519" -w
  ```
  到新电脑后重新导入，或用 `generate_keys` 重新生成一套（需同步更新 App 里的 `SUPublicEDKey`）。

## 五、验证

- 本地验证 appcast 已签名：`cat release/appcast.xml` 里每条 `enclosure` 应带 `sparkle:edSignature="..."`。
- 验证 App 已链接 Sparkle：
  ```sh
  otool -L "Cyan Clone.app/Contents/MacOS/CyanClone" | grep -i sparkle
  codesign --verify --deep --strict "Cyan Clone.app"
  ```

## 六、注意

- 本项目是 **ad-hoc 签名**（非开发者 ID），Sparkle 能检查/下载/提示安装，但 macOS 的
  Gatekeeper 提示会比签名版更明显；若要静默自动安装，建议后续补 Developer ID 签名 + 公证。
- `release/` 目录里的 `appcast.xml` 与 DMG 是发布物，`old_updates/` 是历史版本，可自行排除出 git。
