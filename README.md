# ImmortalWrt 25.x for NRadio C8-688 (HC-WT9104)
针对 **NRadio C8-688**（原厂硬件代号 `HC-WT9104`）深度适配的 ImmortalWrt 固件定制项目。  
采用原厂完整硬件拓扑与设备树定义，深度加固 DualBoot（A/B 双槽位）物理隔离机制，并针对联发科 MT5700M 5G 模组与温控风扇进行了底层适配。
---
## 🌟 硬件规格与原生架构特性
* **SoC**：MediaTek Filogic 820 (MT7981B) 双核 Cortex-A53 @ 1.3GHz
* **内存 (RAM)**：1024MB (1GB) DDR4
* **存储 (eMMC)**：8GB 高速 eMMC（引脚复用严格遵循原厂 `emmc_45`）
* **以太网交换拓扑 (DSA)**：
  * 原厂 **MT7531** 交换芯片（MDIO 地址 31，复位引脚 GPIO 39）
  * CPU GMAC0 / GMAC1 双 2.5G fixed-link 架构
  * 物理端口划分：`lan1`、`lan2`、`lan3`（千兆 LAN）与 `wan`（2.5G 高速 WAN 口，外置 PHY5）
* **无线网络**：
  * MT7981B 内置 Wi-Fi 6，支持 2.4G & 5G 独立射频
  * 默认启用稳定低延时信道方案（5G 频段锁定 Channel 36，80MHz，规避 CAC 雷达退避）
* **5G 蜂窝模组适配**：
  * 原厂硬件电源控制：启动阶段自动拉低 `GPIO 31`（`cpe-pwr`）使能模组供电
  * 控制引脚导出：`GPIO 29`（`cpe-sel0`）与 `GPIO 30`（`cpe-sel1`）
  * 数据网卡自适应：全自动兼容板载直连 `eth2`、USB `usb0` 及 `wwan0`
  * 串口动态嗅探：自动探测 `/dev/ttyUSB1` 与 `/dev/ttyUSB2` 可用性，内置防并发原子锁
* **主动散热**：
  * 原厂 PWM 硬件调速风扇（引脚组 `pwm0_0`，周期 40000），由 `GPIO 27` 提供硬件供电
---
## 🛡️ 安全与双系统 (DualBoot) 机制
* **物理隔离烧录 (Slot B)**：
  * 本固件升级与在线更新**仅写入 Slot B**（Kernel: `/dev/mmcblk0p8`，Rootfs: `/dev/mmcblk0p9`）。
  * 原厂出厂系统（Slot A，位于 `p7` 及相关分区）保持物理绝缘只读，彻底杜绝刷机变砖。
* **7GB eMMC 空间自动利用**：
  * 首次开机自动检测空闲数据分区（`/dev/mmcblk0p10`），安全格式化为 F2FS 并扩容挂载为 `/overlay`。
* **硬件级长按盲切救砖**：
  * 机身 **Reset 按键（GPIO 1）长按 10 秒以上松开**，底层将无条件向 U-Boot 写入回退变量（`boot_part=1` & `boot_system=1`）并强制重启回到原厂系统。
* **Web 端管理**：
  * 集成【系统】->【双系统切换】面板（带 CSRF 校验与 75 秒重启重连遮罩）。
  * 集成【系统】->【在线更新】控制台（直连 GitHub Release，支持云端 SHA256 完整性双校验）。
---
## 🚀 默认系统配置

| 项目 | 默认参数 |
| :--- | :--- |
| **管理后台地址** | `http://192.168.66.1` |
| **默认账户** | `root` |
| **默认密码** | 无密码（首次登录直接回车） |
| **2.4G Wi-Fi** | SSID: `NRadio-C8-688-2.4G` / 密码: `12345678` |
| **5G Wi-Fi** | SSID: `NRadio-C8-688-5G` / 密码: `12345678` |
| **防火墙与加速** | MTK PPE 硬件加速 + FullCone NAT + TCP BBR 拥塞控制 |
| **出站蜂窝规则** | 蜂窝网口出站 TTL 锁定为 64，MSS 自动钳制 |

---
## 🛠️ 仓库核心文件结构
```text
├── .github/workflows/
│   └── build-immortalwrt.yml      # GitHub Actions 全自动多线程编译与 Release 发布流水线
├── c8-688.config                  # 内核驱动、MT7531 DSA 驱动、5G 工具链及 LuCI 插件配置
├── diy-part1.sh                   # Feeds 预加载与缓存清理脚本
├── diy-part2.sh                   # 设备树注入、板级 DSA 网口映射、模组保护与 Web 控制器注入
├── mt7981b-nradio-c8-688.dts      # 严格对标原厂的硬件设备树源码 (MT7531/eMMC/GPIO31/PWM)
└── README.md                      # 项目说明文档