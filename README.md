<div align="center">
  <h1><b>SideStore (zh-CN)</b></h1>
  <p><i>基于 SideStore 的简体中文版，支持应用内中英文切换（重启后生效）</i></p>

  [![Build SideStore-zh_CN](https://github.com/KSLengYu/SideStore-zh_CN/actions/workflows/build.yml/badge.svg?branch=LiveContainerSupport)](https://github.com/KSLengYu/SideStore-zh_CN/actions/workflows/build.yml)
  [![Nightly Release](https://img.shields.io/github/v/release/KSLengYu/SideStore-zh_CN?include_prereleases&label=Nightly%20IPA)](https://github.com/KSLengYu/SideStore-zh_CN/releases/tag/nightly)
  [![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
</div>

<p align="center">
  <b>简体中文</b> | <a href="./README_en.md">English</a>
</p>

> [!NOTE]
> **分支说明**：  
> 本仓库是基于 [LiveContainer/SideStore (`LiveContainerSupport` 分支)](https://github.com/LiveContainer/SideStore) 的 **SideStore 独立版简体中文分支**，同时也是 [KSLengYu/LiveContainer-SideStore-zh_CN](https://github.com/KSLengYu/LiveContainer-SideStore-zh_CN) 合体版的内置 SideStore 来源仓库。

## 本分支说明

- **完整简体中文化**：涵盖主界面、动态页、软件源、浏览、我的应用、设置、储存空间浏览器、恢复与备份、新手引导及 Apple ID 登录页面。
- **应用内语言切换（重启后生效）**：在「设置 → 个性化外观 → 语言」中支持在 `简体中文` 与 `English` 间切换，修改后保留当前界面直到重启生效。
- **Apple ID 登录（`-80045`）与异常恢复优化**：默认关闭存在兼容问题的设备端独立 Anisette，并在连续登录失败或出现 `-80045` 异常时提供关闭设备端独立 Anisette 与重置 `adi.pb` 的恢复弹窗。
- **GitHub Actions 自动打包**：每次推送至 `LiveContainerSupport` 分支会自动构建并发布独立版 **`SideStore-zh_CN.ipa`**。

## 下载独立版安装包

- [前往 Releases 下载最新 `SideStore-zh_CN.ipa`](https://github.com/KSLengYu/SideStore-zh_CN/releases/tag/nightly)（[直接下载 Nightly 构建](https://github.com/KSLengYu/SideStore-zh_CN/releases/download/nightly/SideStore-zh_CN.ipa)）

---

## SideStore 简介

> SideStore 是一款面向未越狱 iOS 设备的开源社区驱动侧载应用商店（基于 [AltStore](https://github.com/rileytestut/AltStore)）。

- **无需电脑即可在设备端签名与续签**：SideStore 使用你的个人开发者证书（Apple ID）重签名应用，并配合 [LocalDevVPN](https://github.com/jkcoxson/LocalDevVPN) / [EM Proxy](https://github.com/jkcoxson/em_proxy) 在设备本地完成安装与 7 天后台自动续期刷新。
- **核心组件**：
  - **AltStore / SideStore App**：应用下载、源管理、证书签名与刷新的主界面与核心逻辑。
  - **EM Proxy**：提供本地回环网络隧道以支持无电脑续签。
  - **Minimuxer**：在 iOS 沙盒内实现 usbmuxd / lockdown 通信协议与本机配对交互。
  - **Roxas**：源自 AltStore 的基础组件库。

## 编译要求

- Xcode
- iOS 14+
- Rustup（`brew install rustup`）

更多源码编译与贡献说明请参考 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## 开源协议

本项目基于 **AGPLv3** 协议开源，详见 [LICENSE](./LICENSE)。
