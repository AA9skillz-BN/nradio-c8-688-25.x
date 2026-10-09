# 🚀 NRadio C8-688 ImmortalWrt DualBoot 固件
专为 NRadio C8-688（MT7981B + 1GB RAM + 8GB eMMC）量身打造的高性能、高稳定性 A/B 双系统定制固件。
---
## 🌟 核心特性亮点
- 🧠 **1GB RAM 物理内存映射**：通过重构内核 DTS 内存节点（`0x40000000 - 0x80000000`），完整释放 1GB 内存容量，保障多任务与并发稳定性[span_0](start_span)[span_0](end_span)。
- 🛡️ **A/B 双系统物理隔离架构**：
  - **Slot A（主槽位）**：保留原厂出厂系统，物理隔离，互不干扰。
  - **Slot B（副槽位）**：专属 ImmortalWrt 固件空间（Kernel: `/dev/mmcblk0p8`，Rootfs: `/dev/mmcblk0p9`）[span_1](start_span)[span_1](end_span)。
  - **救砖机制**：实体 Reset 按键支持长按 10 秒强制切回 Slot A 原厂系统[span_2](start_span)[span_2](end_span)。
- 💾 **系统与数据物理隔离设计**：
  - 系统槽位严格约束在安全的 512MB 物理边界，杜绝越界覆写风险[span_3](start_span)[span_3](end_span)。
  - 剩余 6.5GB+ eMMC 空间（`/dev/mmcblk0p10`）保留为独立数据存储，系统重置或 OTA 升级时个人数据永不丢失[span_4](start_span)[span_4](end_span)[span_5](start_span)[span_5](end_span)。
- 📶 **5G 工业级网络栈支持**：
  - 原生集成 MT5700M 模组控制面板，支持锁频、锁基站、SA/NSA 模式切换与网页端 AT 控制台交互[span_6](start_span)[span_6](end_span)[span_7](start_span)[span_7](end_span)。
  - 模组串口访问集成原子排他锁与进程信号捕获，避免串口资源竞争[span_8](start_span)[span_8](end_span)。
  - 内置 5G 网络自愈看门狗与基站 NITZ 自动授时机制[span_9](start_span)[span_9](end_span)。
  - 支持 IPv6 Relay（中继/穿透）穿透与防火墙防限速 TTL 锁定[span_10](start_span)[span_10](end_span)。
- ❄️ **硬件 PWM 智能温控**：驱动芯片原生 PWM 硬件接口，配合 H5000M 温控面板实现风扇转速随温度自适应调节[span_11](start_span)[span_11](end_span)[span_12](start_span)[span_12](end_span)。
- ⚡ **内核传输深度加速**：开启 MTK 硬件网络加速（Flowtable/PPE）、FullCone NAT 与内核级 TCP BBR 拥塞控制[span_13](start_span)[span_13](end_span)[span_14](start_span)[span_14](end_span)[span_15](start_span)[span_15](end_span)。
- 🔄 **GitHub Release 在线 OTA 升级**：集成 Web 端一键版本检测与静默升级逻辑，固件刷入过程强制锁定 Slot B 分区[span_16](start_span)[span_16](end_span)。
---
## 🖥 默认系统参数

| 参数项 | 默认配置信息 |
| :--- | :--- |
| **后台 IP 地址** | `192.168.66.1`[span_17](start_span)[span_17](end_span)[span_18](start_span)[span_18](end_span) |
| **默认账户** | `root`[span_19](start_span)[span_19](end_span) |
| **默认密码** | 无密码（首次登录直接回车进入，随后提示设置） |
| **默认无线名称** | `NRadio-C8-688-2.4G` / `NRadio-C8-688-5G`[span_20](start_span)[span_20](end_span)[span_21](start_span)[span_21](end_span) |
| **默认无线密码** | `12345678`[span_22](start_span)[span_22](end_span) |
| **5G 频段参数** | 36 信道，HE160 模式（160MHz 频宽）[span_23](start_span)[span_23](end_span) |
| **固件引导槽位** | 副系统 Slot B[span_24](start_span)[span_24](end_span) |

---
## 🧭 后台功能导航
- 📊 **状态 (Status)**：查看 1GB 内存占用、CPU 温度、系统负载与网络流量[span_25](start_span)[span_25](end_span)[span_26](start_span)[span_26](end_span)。
- 📶 **蜂窝网络 (Cellular)**：
  - **MT5700M 5G 管理**：模组运行状态、射频模式（SA/NSA）切换、锁频锁小区、AT 指令交互[span_27](start_span)[span_27](end_span)[span_28](start_span)[span_28](end_span)。
  - **基站信号看板 (3Ginfo)**：查看 RSRP、RSRQ、SINR 及基站物理小区 ID（PCI）[span_29](start_span)[span_29](end_span)[span_30](start_span)[span_30](end_span)。
  - **短信管理**：在线查看与收发 SIM 卡短信[span_31](start_span)[span_31](end_span)[span_32](start_span)[span_32](end_span)。
- ⚙️ **服务 (Services)**：
  - **CPE 温控风扇**：配置硬件 PWM 温控策略与触发转速[span_33](start_span)[span_33](end_span)[span_34](start_span)[span_34](end_span)。
- 🌐 **网络 (Network)**：
  - **接口 / 无线**：配置双频 Wi-Fi 6 与有线局域网[span_35](start_span)[span_35](end_span)。
  - **Turbo ACC 网络加速**：硬件 PPE 流控转发与 BBR 拥塞控制状态[span_36](start_span)[span_36](end_span)[span_37](start_span)[span_37](end_span)[span_38](start_span)[span_38](end_span)。
- 💻 **系统 (System)**：
  - 🔄 **双系统切换**：一键在 Slot A 原厂与 Slot B 之间切换引导槽位[span_39](start_span)[span_39](end_span)[span_40](start_span)[span_40](end_span)。
  - 🚀 **在线更新**：检测 GitHub Release 最新版本并安全写入 Slot B[span_41](start_span)[span_41](end_span)[span_42](start_span)[span_42](end_span)。
  - 📁 **挂载点**：手动将剩余的 6.5GB 独立 eMMC 分区挂载至指定目录（如 `/mnt/data`）[span_43](start_span)[span_43](end_span)。
  - 🎨 **Argon 配置**：定制管理后台主题风格与登录壁纸[span_44](start_span)[span_44](end_span)[span_45](start_span)[span_45](end_span)。
---
## 🛠️ 数据分区手动挂载指南
为了保证系统的纯净与绝对稳定性，系统根目录限制在 512MB 物理边界内，未分配的 6.5GB+ eMMC 空间可手动挂载使用[span_46](start_span)[span_46](end_span)：
### 方式一：Web 界面操作
1. 打开路由管理后台，进入 **【系统】 ➔ 【挂载点】**。
2. 在下方“挂载点”列表中点击 **【添加】**。
3. **设备** 选择剩余数据分区（通常显示为 `/dev/mmcblk0p10`）。
4. **挂载点** 输入自定义路径（例如 `/mnt/data`）。
5. 勾选 **启用此挂载点**，点击“保存并应用”即可生效。
### 方式二：终端命令行操作
通过 TTYD 终端或 SSH 连接后执行以下命令：
```bash
# 1. 格式化数据分区为 f2fs（仅首次需要执行）
mkfs.f2fs -f /dev/mmcblk0p10
# 2. 配置开机自启并生效挂载
mkdir -p /mnt/data
uci add fstab mount
uci set fstab.@mount[-1].device='/dev/mmcblk0p10'
uci set fstab.@mount[-1].target='/mnt/data'
uci set fstab.@mount[-1].enabled='1'
uci commit fstab
/etc/init.d/fstab reload
## 🤝 致谢与开源项目
ImmortalWrt Project
​FAN789/luci-app-mt5700m  
​FAN789/luci-app-h5000m-fancontrol  
​4IceG/luci-app-sms-tool-js  
​4IceG/luci-app-3ginfo-lite  
​jerrykuku/luci-theme-argon
