<div align="center">
  <h1><b>SideStore (zh-CN)</b></h1>
  <p><i>Simplified Chinese standalone edition of SideStore with in-app Chinese/English switching (restart required)</i></p>

  [![Build SideStore-zh_CN](https://github.com/KSLengYu/SideStore-zh_CN/actions/workflows/build.yml/badge.svg?branch=LiveContainerSupport)](https://github.com/KSLengYu/SideStore-zh_CN/actions/workflows/build.yml)
  [![Nightly Release](https://img.shields.io/github/v/release/KSLengYu/SideStore-zh_CN?include_prereleases&label=Nightly%20IPA)](https://github.com/KSLengYu/SideStore-zh_CN/releases/tag/nightly)
  [![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
</div>

<p align="center">
  <a href="./README.md">简体中文</a> | <b>English</b>
</p>

> [!NOTE]
> **Branch Info**:  
> This repository is the Simplified Chinese standalone branch based on [LiveContainer/SideStore (`LiveContainerSupport`)](https://github.com/LiveContainer/SideStore), and serves as the embedded SideStore source for [KSLengYu/LiveContainer-SideStore-zh_CN](https://github.com/KSLengYu/LiveContainer-SideStore-zh_CN).

## What's Changed

- **Full Simplified Chinese Localization**: Complete Chinese localization generated via [`scripts/generate_full_strings.py`](./scripts/generate_full_strings.py) covering News, Sources, Browse, My Apps, Settings, Storage Browser, Restore/Backup, Onboarding, and Apple ID Sign-In.
- **In-App Language Switching (Restart Required)**: Supports switching between `简体中文` and `English` under **Settings → Personalization → Language**, taking effect on next launch.
- **Apple ID Sign-In & Recovery Improvements**: Improved `-80045` / Anisette handling and added a recovery alert on repeated sign-in failures to disable On-Device Anisette and reset `adi.pb`.
- **Automated CI**: Automatically builds and publishes standalone **`SideStore-zh_CN.ipa`** via GitHub Actions on pushes to `LiveContainerSupport`.

## Download

- [Latest Nightly Release (`SideStore-zh_CN.ipa`)](https://github.com/KSLengYu/SideStore-zh_CN/releases/tag/nightly) ([Direct Download](https://github.com/KSLengYu/SideStore-zh_CN/releases/download/nightly/SideStore-zh_CN.ipa))

---

# SideStore

> SideStore is an *untethered, community driven* alternative app store for non-jailbroken iOS devices.

SideStore is an iOS application that allows you to sideload apps onto your iOS device with just your Apple ID. SideStore resigns apps with your personal development certificate, and uses a [specially designed VPN](https://github.com/jkcoxson/em_proxy) in order to trick iOS into installing them. SideStore periodically refreshes your apps in the background to keep their 7-day development period from expiring.

SideStore is a community driven fork of [AltStore](https://github.com/rileytestut/AltStore).

## Requirements
- Xcode 15+
- iOS 14+
- Rustup (`brew install rustup`)

## Project Overview

### SideStore
SideStore is a sandboxed iOS application. The AltStore app target contains the core functionality for downloading, signing, and updating apps through SideStore.

### EM Proxy
[EM Proxy](https://github.com/jkcoxson/em_proxy) powers untethered installation by leveraging a loopback VPN tunnel ([LocalDevVPN](https://github.com/jkcoxson/LocalDevVPN)) without requiring a paid developer account.

### Minimuxer
[Minimuxer](https://github.com/jkcoxson/minimuxer) is a lockdown muxer running inside iOS's sandbox that replicates Apple's usbmuxd protocol to interface with LocalDevVPN on-device.

### Roxas
[Roxas](https://github.com/rileytestut/roxas) is Riley Testut's internal framework from AltStore used across iOS projects.

## Contributing / Building

Please see [CONTRIBUTING.md](./CONTRIBUTING.md).

## Licensing

This project is licensed under the **AGPLv3 license**. See [LICENSE](./LICENSE).
