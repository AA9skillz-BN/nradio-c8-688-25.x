cat << 'EOF' > README.md
<div align="center">

# 🚀 NRadio C8-688 ImmortalWrt DualBoot 固件

**专为 NRadio C8-688 (MT7981B + 1GB RAM + 8GB eMMC) 打造的满血极速、双系统无损共存固件**

[![Build Status](https://img.shields.io/github/actions/workflow/status/AA9skillz-BN/nradio-c8-688-25.x/build-immortalwrt.yml?branch=main&style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/AA9skillz-BN/nradio-c8-688-25.x/actions)
[![Latest Release](https://img.shields.io/github/v/release/AA9skillz-BN/nradio-c8-688-25.x?style=for-the-badge&logo=github&color=blue)](https://github.com/AA9skillz-BN/nradio-c8-688-25.x/releases)
[![ImmortalWrt](https://img.shields.io/badge/ImmortalWrt-24.10-red?style=for-the-badge&logo=openwrt)](https://immortalwrt.org/)
[![License](https://img.shields.io/badge/License-GPL%20v3-green?style=for-the-badge)](LICENSE)

<p align="center">
  <b>1GB 物理内存映射</b> • 
  <b>8GB eMMC 动态全容量释放</b> • 
  <b>MT5700M 蜂窝专属顶层面板</b> • 
  <b>双系统 A/B 无损隔离</b> • 
  <b>在线 OTA 一键更新</b>
</p>

---

</div>

## 🌟 核心特性

- 🧠 **1GB RAM 满血激活**：内核 DTS 物理内存重构，告别 512MB 限制，大内存多开无压力。
- 🛡️ **A/B 双系统无损隔离**：
  - **Slot A**：原厂出厂系统，永不冲刷，永不污染。
  - **Slot B**：ImmortalWrt 专属副系统，支持网页端一键安全切换、重启秒切。
- 📶 **专属「蜂窝网络」顶级大分类**：
  - 深度集成 **MT5700M 5G 模组** 控制面板（锁定频段 / 锁定小区 / SA·NSA 制式切换 / 实时信号看板 / 网页端 AT 终端）。
  - 自动绑定通信串口 `/dev/ttyUSB1`。
- 💾 **8GB eMMC 自适应动态扩容**：
  - 首次开机自适应扩展底层物理扇区，`/overlay` 自动撑满释放 **6GB+** 可用空间。
- ❄️ **智能硬件级温控**：
  - 驱动 MT7981B 硬件 PWM，集成 H5000M 智能温控风扇面板，支持温度自适应调速与全速模式。
- ⚡ **Turbo ACC 网络加速**：
  - MTK 硬件 PPE 芯片级转发加速、FullCone NAT、BBR 拥塞控制算法。
- 🔄 **GitHub Release 在线 OTA 一键更新**：
  - Web 后台图形化检查更新，自动下载并防冲刷写入 Slot B，平滑升级不掉配置。

---

## 🖥️ 默认配置信息

| 项目 | 默认参数 |
| :--- | :--- |
| **后台 IP** | `192.168.66.1` |
| **用户名** | `root` |
| **默认密码** | `password` 或 `空` (无密码) |
| **默认主题** | Argon (适配暗黑/白天模式) |
| **运行槽位** | 副系统 Slot B (`mmcblk0p8` 内核 + `mmcblk0p9` 根分区) |

---

## 🧭 后台 Web 菜单一览

```text
├── 📊 状态 (Status)
├── 📶 蜂窝网络 (Cellular) ──────── 5G 模组管理 (MT5700M) / 锁频锁网 / AT 终端
├── ⚙️ 服务 (Services) ─────────── CPE 智能温控风扇管理 (H5000M)
├── 🌐 网络 (Network) ──────────── 接口 / 无线 / Turbo ACC 网络加速
└── 💻 系统 (System)
    ├── 🔄 双系统切换 (DualBoot) ── 一键在 Slot A 原厂与 Slot B 之间切换
    ├── 🚀 在线更新 (AutoUpdate) ── 一键检测 GitHub Release 并静默升级
    └── 🎨 Argon 配置 ─────────── 登录壁纸与外观定制
