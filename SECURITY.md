# Cyan Clone · 安全说明

一句话：**你的数据只在本机，不会上传；自动更新有数字签名，别人推不了假更新。**

## 一、数据完全本地化

- Cyan Clone 只读本地目录，建立的是「目录索引」（名称 / 大小 / 修改时间 / 层级），**不复制文件内容**。
- 索引文件只存在本机：`~/Library/Application Support/Cyan Clone/index.json`。
- 全部源码**没有任何联网上传代码**（无 URLSession / 网络请求）。
  唯一的网络行为是「检查更新」时**下载** appcast 和新版本 DMG——只读不写、不上传任何本地数据。

## 二、自动更新防劫持（EdDSA 签名）

- 每次更新都由 EdDSA 数字签名保护：
  - `appcast.xml` 带 `sparkle:edSignature`；
  - 下载的 DMG 也带 `edSignature`。
- App 内置公钥（Info.plist 的 `SUPublicEDKey`）用来验签。
  **只有持有私钥的人能发布更新**：别人即使拿到你的 appcast 地址，也伪造不了更新——
  没有你私钥签名的包会被 App 直接拒绝，不会安装。

## 三、私钥是唯一需要保护的资产

- 私钥只存在**本机钥匙串**（account `ed25519`、service `https://sparkle-project.org`），不在任何文件里。
- 保护好它 = 保护好你的 Mac 登录密码和钥匙串；**不要把它导出成明文文件发给任何人**。
- 换电脑发版前导出（见 `RELEASING.md`）：
  ```sh
  security find-generic-password -s "https://sparkle-project.org" -a "ed25519" -w
  ```

## 四、已知弱项（诚实说明）

- App 目前是 **ad-hoc 签名**（未注册 Apple 开发者 ID），macOS 首次打开会提示「未验证开发者」。
- 这不影响更新安全（验签靠 EdDSA，不靠 Apple 证书），但 Gatekeeper 提示更明显；
  若要完全静默安装并去掉警告，需注册 Apple Developer Program 做 Developer ID 签名 + 公证。

## 五、自查清单

```sh
# 1. 索引确实只在本地
ls ~/Library/Application\ Support/Cyan\ Clone/

# 2. 项目里没有明文私钥文件（应无输出）
find . -type f \( -iname '*.pem' -o -iname '*.key' -o -iname 'dsa*' \) | grep -v Vendor

# 3. 更新源必须是 https
/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "Cyan Clone.app/Contents/Info.plist"
```
