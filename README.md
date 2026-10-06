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

 * 登录设备终端，解压并直接烧录至副系统分区：
   # 解压固件包
cd /tmp
tar -tf sysupgrade.bin

# 写入 Slot B 内核与根文件系统
tar -xf sysupgrade.bin sysupgrade-nradio_c8-688/kernel -O > /dev/mmcblk0p8
tar -xf sysupgrade.bin sysupgrade-nradio_c8-688/root -O > /dev/mmcblk0p9

# 设置引导至 Slot B 并重启
fw_setenv boot_part 2
sync
reboot

 * 设备重启后：
   * 搜索 Wi-Fi：NRadio-C8-688-5G（密码：12345678）
   * 登录后台：http://192.168.66.1（用户名：root，密码为空）
日常运维与灾难恢复
1. 灾难救砖（硬件级）
当副系统（Slot B）因配置错误、网络中断或软件冲突无法访问后台时：
 * 操作：使用卡针长按机身 Reset 键 10 秒以上 后松手。
 * 结果：系统自动切换 U-Boot 引导变量至 boot_part=1 并自动重启，直接切回出厂原厂系统。
2. 在线 OTA 更新（软件级）
 * 登录 LuCI 后台，进入 【系统】 -> 【在线更新】。
 * 点击 “🔍 仅检查新版本” 可自动比对 GitHub Releases 最新标签。
 * 点击 “🚀 一键在线升级并重启”，后台将自动下载、校验 SHA256 并将新固件重新写入 Slot B。
3. 命令行手动升级
登录后台 TTYD 终端，直接执行：
/usr/bin/c8_autoupdate

仓库构建结构
├── .github/workflows/
│   └── build.yml               # GitHub Actions 全自动多线程编译工作流
├── mt7981b-nradio-c8-688.dts   # 设备专属设备树（支持 A/B 分区表映射与引脚定义）
├── c8-688.config               # 固件完整内核与软件包依赖配置
├── diy-part1.sh                # 源码 feeds 拓展脚本
├── diy-part2.sh                # 核心调优、驱动注入、脚本下发与防火墙规则构建
└── README.md

鸣谢与上游开源项目
 * ImmortalWrt Project
 * OpenWrt Project
 * luci-app-mt5700m & fancontrol by FAN789
 * luci-app-sms-tool-js & 3ginfo-lite by 4IceG
 * luci-theme-argon by jerrykuku

---

### 如果在终端中操作（免手动创建文件）

如果你正打开着本地终端或远程连接环境，可以直接复制下面这条命令回车，它会自动创建并写入 `README.md`：

```bash
cat << 'EOF' > README.md
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

 * 登录设备终端，解压并直接烧录至副系统分区：
   cd /tmp
tar -xf sysupgrade.bin sysupgrade-nradio_c8-688/kernel -O > /dev/mmcblk0p8
tar -xf sysupgrade.bin sysupgrade-nradio_c8-688/root -O > /dev/mmcblk0p9
fw_setenv boot_part 2
sync
reboot

 * 设备重启后：
   * 搜索 Wi-Fi：NRadio-C8-688-5G（密码：12345678）
   * 登录后台：http://192.168.66.1（用户名：root，密码为空）
日常运维与灾难恢复
1. 灾难救砖（硬件级）
当副系统（Slot B）因配置错误、网络中断或软件冲突无法访问后台时：
 * 操作：使用卡针长按机身 Reset 键 10 秒以上 后松手。
 * 结果：系统自动切换 U-Boot 引导变量至 boot_part=1 并自动重启，直接切回出厂原厂系统。
2. 在线 OTA 更新（软件级）
 * 登录 LuCI 后台，进入 【系统】 -> 【在线更新】。
 * 点击 “🔍 仅检查新版本” 可自动比对 GitHub Releases 最新标签。
 * 点击 “🚀 一键在线升级并重启”，后台将自动下载、校验 SHA256 并将新固件重新写入 Slot B。
3. 命令行手动升级
登录后台 TTYD 终端，直接执行：
/usr/bin/c8_autoupdate

仓库构建结构
├── .github/workflows/
│   └── build.yml               # GitHub Actions 全自动多线程编译工作流
├── mt7981b-nradio-c8-688.dts   # 设备专属设备树（支持 A/B 分区表映射与引脚定义）
├── c8-688.config               # 固件完整内核与软件包依赖配置
├── diy-part1.sh                # 源码 feeds 拓展脚本
├── diy-part2.sh                # 核心调优、驱动注入、脚本下发与防火墙规则构建
└── README.md

鸣谢与上游开源项目
 * ImmortalWrt Project
 * OpenWrt Project
 * luci-app-mt5700m & fancontrol by FAN789
 * luci-app-sms-tool-js & 3ginfo-lite by 4IceG
 * luci-theme-argon by jerrykuku
   EOF

<Elicitations message="复制完成后，接下来您希望：">
  <Elicitation label="推送到远程仓库开始编译" query="请提供在本地终端执行 git add、commit 和 push 的一键推送命令。"/>
  <Elicitation label="了解 Actions 编译时长与产物" query="GitHub Actions 首次编译大概需要多长时间，生成的固件文件叫什么名字？"/>
</Elicitations>
