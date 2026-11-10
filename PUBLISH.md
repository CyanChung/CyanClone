# Cyan Clone · 上传到 GitHub（首次发布）

本地仓库已经准备好（`git init` + 首次提交 + `origin` 已指向 `CyanChung/CyanClone`），
你只差三步：**建仓库 → 推代码 → 发首个版本**。

> 本文档是「首次上传」。以后每次发新版看 [RELEASING.md](RELEASING.md)。

## 项目本地位置

```
/Users/cyan/WorkBuddy/2026-11-09-16-27-33/CyanClone
```

下面的命令都在这个目录下执行。

---

## 第 1 步 · 创建 GitHub 仓库

1. 浏览器打开 **https://github.com/new**（已登录 CyanChung）
2. **Repository name** 填 `CyanClone`
3. 选 **Public**
4. ⚠️ 三个初始化选项**都不勾**：
   - ❌ Add a README file
   - ❌ Add .gitignore
   - ❌ Choose a license
5. 点 **Create repository**

---

## 第 2 步 · 推送代码

### 方式 A：命令行（推荐）

**先准备 token：**
1. 打开 https://github.com/settings/tokens
2. **Generate new token** → **Generate new token (classic)**
3. Note 随便填；Expiration 选 90 天或 No expiration
4. 勾选 **`repo`**（自动带上子项）
5. 生成，复制 `ghp_` 开头的字符串（只显示一次）

**再执行推送**（终端 App）：
```bash
cd "/Users/cyan/WorkBuddy/2026-11-09-16-27-33/CyanClone"
git push -u origin main
```
- `Username` → `CyanChung`
- `Password` → 粘贴 token（不显示字符，正常）

看到 `Branch 'main' set up to track ...` 即成功。

### 方式 B：GitHub Desktop（不熟命令行用这个）

1. 下载安装 https://desktop.github.com ，登录账号
2. **File → Add Local Repository** → 选 `/Users/cyan/WorkBuddy/2026-11-09-16-27-33/CyanClone`
3. 右上 **Publish repository** → Name 填 `CyanClone` → 取消勾选 "Keep this code private" → **Publish**

---

## 第 3 步 · 发布第一个版本（让「检查更新」生效）

1. 打开 **https://github.com/CyanChung/CyanClone** → 右侧 **Releases** → **Create a new release**
2. **Choose a tag** 输入 `v1.29` → 回车 → 点 **Create new tag: v1.29**
3. **Release title** 填 `v1.29`
4. 下方 **Attach binaries** 上传这两个文件（在 `release/` 目录里）：
   - `Cyan Clone 1.29.dmg`
   - `appcast.xml`
5. 点 **Publish release**

完成后，App 里「关于 → 检查更新」就能连上，收到后续版本。

---

## 以后每次更新（三步）

1. 改 `build.sh` 里两处版本号（`1.29`→`1.30`、`29`→`30`）
2. 终端执行：
   ```bash
   cd "/Users/cyan/WorkBuddy/2026-11-09-16-27-33/CyanClone"
   ./build.sh
   ./publish_update.sh 1.30 "这次改了什么"
   ```
3. GitHub 建新 release `v1.30`，上传新的 `Cyan Clone 1.30.dmg` + `appcast.xml`

> 详细原理（密钥、签名、appcast）见 [RELEASING.md](RELEASING.md)；安全说明见 [SECURITY.md](SECURITY.md)。
