# NRadio C8-688 商业级 5G CPE 专属 ImmortalWrt 固件
[![Build ImmortalWrt for NRadio C8-688](https://github.com/AA9skillz-BN/nradio-c8-688-25.x/actions/workflows/build.yml/badge.svg)](https://github.com/AA9skillz-BN/nradio-c8-688-25.x/actions)
[![Release](https://img.shields.io/github/v/release/AA9skillz-BN/nradio-c8-688-25.x?color=blue&label=Latest%20Release)](https://github.com/AA9skillz-BN/nradio-c8-688-25.x/releases)
[![OpenWrt](https://img.shields.io/badge/ImmortalWrt-25.x-orange.svg)](https://github.com/immortalwrt/immortalwrt)
[![Kernel](https://img.shields.io/badge/Linux%20Kernel-6.12-green.svg)](https://kernel.org/)
[![Hardware](https://img.shields.io/badge/Platform-MediaTek%20Filogic%20820%20(MT7981B)-brightgreen.svg)]()
专为 **NRadio（数传）C8-688 / C8-668** 5G CPE 定制的商业级 ImmortalWrt 固件。深度适配 **MediaTek MT7981B + MT5700M 5G 模组** 架构，搭载完整 A/B 双系统容灾机制、蜂窝链路断网自愈、防热点限速伪装、IPv6 Relay 穿透及内核级硬件加速引擎。
---
## 规格参数与出厂预设

| 项目 | 默认配置 |
| :--- | :--- |
| **设备型号** | NRadio C8-688 / C8-668 (MediaTek MT7981B / Filogic 820) |
| **默认后台地址** | `192.168.66.1` |
| **默认用户名 / 密码** | `root` / **空（无密码）** |
| **2.4G Wi-Fi** | SSID: `NRadio-C8-688-2.4G` / 密码: `12345678` |
| **5G Wi-Fi** | SSID: `NRadio-C8-688-5G` / 频宽: **160MHz (HE160)** / 密码: `12345678` |
| **系统架构** | **DualBoot A/B 槽位隔离**（本固件强制运行于 Slot B） |
| **存储扩展** | 首次开机自动扩展 8GB eMMC 空间至 `/overlay`（剩余可用空间约 6~7GB） |

---
## 核心特性矩阵
### 1. 工业级容灾与 DualBoot 安全隔离
* **Slot B 专属烧录**：底层升级脚本锁死写入 `mmcblk0p8` (Kernel) 与 `mmcblk0p9` (Rootfs)，原厂 Slot A 系统物理绝缘，永不被冲刷损坏。
* **物理按键 10 秒盲切救砖**：
  * **按压 4~9 秒松手**：重置当前副系统，恢复出厂设置（`firstboot`）。
  * **按压 10 秒以上松手**：底层写入 `fw_setenv boot_part 1` 并强制重启，**无损倒换回原厂主系统（Slot A）**，彻底告别拆机焊接串口救砖。
* **Web 端双系统一键倒换**：LuCI 后台集成“双系统切换”面板，支持图形化平滑切换引导槽位。
### 2. 蜂窝网络与 5G 模组高可用链路
* **免配置插卡即用**：集成 CDC-Ether、RNDIS、NCM、QMI 全协议驱动栈与 `usb-modeswitch`，网络热插拔防抖脚本开机自动纳管外网并绑定防火墙。
* **双阶断网自愈看门狗**：后台常驻检测公网 DNS，两轮丢包自动重启网络接口；四轮超时自动向 `/dev/ttyUSB1` 发送 `AT+CFUN=0/1` 触发射频硬件软复位。
* **NITZ 蜂窝基站毫秒授时**：开机自动通过 AT 指令抓取基站网络时间，解决主板无纽扣电池断电重置为 1970 年导致的 HTTPS 证书与组网握手死锁。
* **蜂窝原生 IPv6 Relay 穿透**：全面联动 `odhcpd`，突破运营商单 `/64` 无 PD 局限，局域网终端免前缀委派直接获取原生公网 IPv6 地址。
* **TCP MSS 智能钳制**：全局匹配蜂窝网络真实 MTU，根除部分 App 与网站由于大包分片导致的图片转圈与断流。
* **TTL / Hop Limit 强制锁定**：基于 nftables 将全局出站数据包 TTL 锁定为 `64`，直接规避运营商针对 CPE 热点共享的流量降速限制。
### 3. 数据流转发与加解密性能压榨
* **MediaTek Flowtable 硬件流控**：有线与无线转发由硬件协处理器接管，千兆满速跑满近乎零 CPU 开销。
* **TCP BBR + FQ**：实装 BBR 拥塞控制与 FQ 队列调度，平抑弱网抖动，大幅提升蜂窝链路吞吐。
* **加密硬加速（Cryptodev & kTLS）**：编译集成 `kmod-cryptodev` 与 `kmod-tls`，释放 ARMv8 Crypto Extensions 硬件加解密潜能，降低代理与隧道高并发下的 CPU 负载。
### 4. 商业级运维管理套件
* **蜂窝专属仪表盘**：顶层菜单收敛集成 `MT5700M 模组控制面板`、`3Ginfo 基站信号监控` 与 `短信收发（sms-tool）`。
* **流量用量防偷跑监视**：预装 `nlbwmon`，精准监控单机用量与结算周期流量，防止 SIM 卡套外资费爆仓。
* **温控智能散热**：板载 PWM 温控风扇驱动，随 CPU/模组热量梯度动态调速。
* **全自动 GitHub OTA 更新**：集成专用更新脚本与 Web 终端面板，一键拉取最新 Release 校验并安全烧录至 Slot B。
* **远程运维与网络诊断**：集成 `Tailscale` 异地穿透组网、`TTYD 网页终端`、`htop`、`iperf3`、`ethtool`。
---
## 首次刷机与安装说明
### 前置条件
确保设备处于原厂系统（Slot A）或已进入支持 U-Boot 引导的环境，并已开启 SSH/Telnet 权限。
### 刷入副系统（Slot B）
1. 下载 Releases 页面中的 `immortalwrt-mediatek-filogic-nradio_c8-688-sysupgrade.bin`。
2. 上传固件至设备的 `/tmp` 目录：
   ```bash
   scp immortalwrt-*-sysupgrade.bin root@192.168.1.1:/tmp/sysupgrade.bin
