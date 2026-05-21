# 微信多开助手开源版

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0+-blue?logo=apple" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-6.2-orange?logo=swift" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  <img src="https://img.shields.io/github/v/release/Markjinli/wechat-multi-opener?color=blue" alt="Release">
</p>

macOS 原生微信多开工具，基于 SwiftUI 构建，支持一键创建多个独立微信实例，每个实例数据完全隔离，可同时登录不同账号。

## 下载安装

👉 [前往 Releases 下载最新版 DMG](https://github.com/Markjinli/wechat-multi-opener/releases/latest)

下载后双击 DMG → 将应用拖入「应用程序」文件夹即可。

> ⚠️ 由于应用未经过 Apple 公证签名，首次打开可能遇到安全提示，请参阅下方[常见问题](#macos-安全提示解决方案)解决。

## 功能特性

| 功能 | 说明 |
|------|------|
| 🔐 密码验证 | 启动时验证管理员密码，安全可靠 |
| ➕ 一键多开 | 选择数量后自动复制微信、修改 Bundle ID、签名、权限一步到位 |
| 🏷️ 名称区分 | 每个副本在 Dock 和应用程序中显示为「微信2」「微信3」等，不再混淆 |
| 🟢 运行检测 | 实时显示每个实例是否运行中 |
| 🗑️ 删除实例 | 支持单独删除某个副本，连同数据一并清理 |
| 🔧 修复多开 | 一键重新签名和修复所有副本 |
| 🔄 刷新检测 | 手动刷新检测已安装的微信实例 |

## 使用方法

1. **打开应用** → 输入电脑开机密码
2. **点击「一键多开微信」** → 选择需要创建的数量
3. 等待创建完成 → 在 Launchpad 或 Spotlight 中打开对应的微信实例
4. 每个实例可独立登录不同微信账号

## 技术原理

每个微信副本通过以下 7 步实现数据隔离：

1. 复制 `WeChat.app` → `WeChat{N}.app`
2. 修改 `CFBundleIdentifier` 为 `com.tencent.xinWeChat{N}`
3. 修改 `CFBundleDisplayName` 为「微信{N}」
4. 遍历所有 `.lproj/InfoPlist.strings` 本地化文件，覆盖显示名称
5. 清除扩展属性 `xattr -cr`
6. Ad-hoc 重签名 `codesign --force --deep --sign -`
7. 修复文件权限 `chown -R`

每个副本的数据存储在独立沙盒目录：

```
~/Library/Containers/com.tencent.xinWeChat/   ← 原版
~/Library/Containers/com.tencent.xinWeChat2/   ← 微信2
~/Library/Containers/com.tencent.xinWeChat3/   ← 微信3
```

## macOS 安全提示解决方案

从 GitHub 下载的应用未经 Apple 公证，macOS 可能会拦截。以下是各种提示的解决方法：

### 情况一：「无法打开，因为它来自身份不明的开发者」

1. 打开 **系统设置 → 隐私与安全性**
2. 在底部找到提示信息，点击 **「仍要打开」**
3. 在弹窗中再次点击「打开」

或者在应用上右键 → 选择 **「打开」** → 在弹窗中点击「打开」。

### 情况二：「已损坏，无法打开」

打开终端，执行以下命令：

```bash
xattr -cr /Applications/微信多开助手开源版.app
```

然后重新打开应用即可。

> 这个问题是因为 macOS 给下载的文件附加了隔离属性（quarantine），上面的命令会清除这些属性。

### 情况三：提示「有风险」或被 Gatekeeper 拦截

如果上述方法都无法解决，可以临时允许任何来源的应用：

```bash
sudo spctl --master-disable
```

然后在 **系统设置 → 隐私与安全性** 中选择 **「任何来源」**，打开应用后建议恢复：

```bash
sudo spctl --master-enable
```

### 情况四：提示需要 Xcode Command Line Tools

本工具依赖 `codesign` 和 `PlistBuddy`，如果未安装：

```bash
xcode-select --install
```

在弹出的安装窗口中点击「安装」即可。

## 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | macOS 13.0 (Ventura) 或更高 |
| 微信版本 | 4.0 或更高 |
| 权限 | 管理员（开机密码） |
| 依赖 | Xcode Command Line Tools |

## 常见问题

<details>
<summary><b>原版微信会被修改吗？</b></summary>

不会。工具只复制原版微信，不会对原版做任何修改。
</details>

<details>
<summary><b>数据会混淆吗？</b></summary>

不会。每个副本使用独立的 Bundle ID，数据存储在独立的沙盒目录，完全隔离。
</details>

<details>
<summary><b>微信更新后副本还能用吗？</b></summary>

副本不会随原版自动更新。如果原版更新后需要同步，可以删除副本后重新创建，或点击「修复多开错误」重新签名。
</details>

<details>
<summary><b>可以创建多少个副本？</b></summary>

单次最多创建 10 个，总数量无硬性限制，取决于磁盘空间。
</details>

<details>
<summary><b>删除副本会清理数据吗？</b></summary>

会。删除时会同时清除应用和 `~/Library/Containers/` 下对应的沙盒数据。
</details>

## 致谢

- 灵感来源于 [nullbyte-lab/wechat-multi-open](https://github.com/nullbyte-lab/wechat-multi-open)
- 本项目将其核心逻辑封装为原生 macOS SwiftUI 应用，并增加了本地化名称修复、运行检测、实例管理等功能

## License

[MIT](LICENSE)
