# 🚀 NRadio C8-688 ImmortalWrt DualBoot 固件
专为 NRadio C8-688（MT7981B + 1GB RAM + 8GB eMMC）量身打造的高性能、高稳定性 A/B 双系统定制固件。
---
## 🌟 核心特性亮点
- 🧠 **1GB RAM 物理内存映射**：通过重构内核 DTS 内存节点（`0x40000000 - 0x80000000`），完整释放 1GB 内存容量，告别 512MB 限制，保障多任务并发稳定性。
- 🛡️ **A/B 双系统物理隔离架构**：
  - **Slot A（主槽位）**：保留原厂出厂系统，物理隔离锁死，互不干扰。
  - **Slot B（副槽位）**：专属 ImmortalWrt 固件空间（Kernel: `/dev/mmcblk0p8`，Rootfs: `/dev/mmcblk0p9`）。
  - **救砖机制**：实体 Reset 按键支持长按 10 秒强制切回 Slot A 原厂系统。
- 💾 **系统与数据物理隔离设计**：
  - 系统根目录严格约束在安全的 512MB 物理边界内，杜绝越界覆写风险。
  - 剩余 6.5GB+ eMMC 空间（`/dev/mmcblk0p10`）保留为独立数据存储，系统重置或 OTA 升级时个人数据永不丢失。
- 📶 **5G 工业级网络栈支持**：
  - 原生集成 MT5700M 模组控制面板，支持 5G 信号看板、锁频、锁基站、SA/NSA 模式切换与网页端 AT 控制台交互。
  - 模组串口访问集成原子排他锁与进程信号捕获，避免串口资源并发死锁。
  - 内置 5G 网络断网自愈看门狗与基站 NITZ 自动授时机制。
  - 支持蜂窝 5G IPv6 Relay（中继/穿透）与防火墙出站防限速 TTL 锁定。
- ❄️ **硬件 PWM 智能温控**：驱动芯片原生 PWM 硬件接口，配合 H5000M 温控面板实现风扇转速随温度自适应调节。
- ⚡ **内核传输深度加速**：开启 MTK 硬件网络加速（PPE / Flowtable）、FullCone NAT 与内核级 TCP BBR 拥塞控制。
- 🔄 **GitHub Release 在线 OTA 升级**：集成 Web 端一键版本检测与静默升级逻辑，固件刷入过程强制锁定 Slot B 分区。
---
## 🖥 默认系统参数

| 参数项 | 默认配置信息 |
| :--- | :--- |
| **后台 IP 地址** | `192.168.66.1` |
| **默认账户** | `root` |
| **默认密码** | 无密码（首次登录直接回车进入，随后提示设置） |
| **默认无线名称** | `NRadio-C8-688-2.4G` / `NRadio-C8-688-5G` |
| **默认无线密码** | `12345678` |
| **5G 频段参数** | 36 信道，HE160 模式（160MHz 满血频宽） |
| **固件引导槽位** | 副系统 Slot B |

---
## 🧭 后台功能导航
- 📊 **状态 (Status)**：实时查看 1GB 内存占用、CPU 温度、系统负载与网络吞吐。
- 📶 **蜂窝网络 (Cellular)**：
  - **MT5700M 5G 管理**：模组运行状态、射频模式（SA/NSA）切换、锁频锁基站、网页 AT 控制台。
  - **基站信号看板 (3Ginfo)**：查看 RSRP、RSRQ、SINR 及基站物理小区 ID（PCI）。
  - **短信管理**：在线查看与收发 SIM 卡短信。
- ⚙️ **服务 (Services)**：
  - **CPE 温控风扇**：配置硬件 PWM 温控策略与阶梯转速。
- 🌐 **网络 (Network)**：
  - **接口 / 无线**：配置双频 Wi-Fi 6 与以太网接口。
  - **Turbo ACC 网络加速**：硬件 PPE 流控转发与 BBR 拥塞控制状态。
- 💻 **系统 (System)**：
  - 🔄 **双系统切换 (DualBoot)**：一键在 Slot A 原厂与 Slot B 之间平滑切换引导槽位。
  - 🚀 **在线更新 (AutoUpdate)**：一键检测 GitHub Release 最新固件版本并安全写入 Slot B。
  - 📁 **挂载点 (Mount Points)**：手动将剩余的 6.5GB 独立 eMMC 分区挂载至指定目录（如 `/mnt/data`）。
  - 🎨 **Argon 配置**：定制管理后台主题风格与登录壁纸。
---
## 🛠️ 数据分区手动挂载指南
为了保证系统的纯净与绝对稳定性，系统根目录限制在 512MB 物理边界内，未分配的 6.5GB+ eMMC 空间可手动挂载使用：
### 方式一：Web 界面操作
1. 打开路由管理后台，进入 **【系统】 ➔ 【挂载点】**。
2. 在下方“挂载点”列表中点击 **【添加】**。
3. **设备** 选择剩余数据分区（通常显示为 `/dev/mmcblk0p10`）。
4. **挂载点** 输入自定义路径（例如 `/mnt/data`）。
5. 勾选 **启用此挂载点**，点击“保存并应用”即可生效。
### 方式二：终端命令行操作
通过 TTYD 终端或 SSH 连接后执行以下命令：
```bash
# 1. 格式化数据分区为 f2fs（仅首次配置需要执行）
mkfs.f2fs -f /dev/mmcblk0p10
# 2. 配置开机自启并生效挂载
mkdir -p /mnt/data
uci add fstab mount
uci set fstab.@mount[-1].device='/dev/mmcblk0p10'
uci set fstab.@mount[-1].target='/mnt/data'
uci set fstab.@mount[-1].enabled='1'
uci commit fstab
/etc/init.d/fstab reload
```
---
## 🤝 致谢与鸣谢 (Acknowledgments)
本项目在方案设计、代码实现与功能调试过程中，深度参考并整合了以下开源项目与社区贡献者的杰出成果。在此向所有开源作者致以崇高的敬意：

| 开源项目 / 依赖组件 | 原作者 / 仓库链接 | 主要用途与技术贡献 |
| :--- | :--- | :--- |
| **ImmortalWrt** | [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) | 提供现代化的 OpenWrt 底层源码树与 MediaTek 目标构建工具链 |
| **luci-app-mt5700m** | [FAN789/luci-app-mt5700m](https://github.com/FAN789/luci-app-mt5700m) | 提供 MT5700M 模组的核心控制、频段锁定与网页 AT 交互面板 |
| **luci-app-h5000m-fancontrol** | [FAN789/luci-app-h5000m-fancontrol](https://github.com/FAN789/luci-app-h5000m-fancontrol) | 提供硬件 PWM 智能温控风扇策略面板与底层驱动适配 |
| **luci-app-autoupdate** | [Hyy2001X/luci-app-autoupdate](https://github.com/Hyy2001X/luci-app-autoupdate) | 提供 GitHub Release 固件检测、哈希校验与 OTA 架构思路 |
| **luci-app-sms-tool-js** | [4IceG/luci-app-sms-tool-js](https://github.com/4IceG/luci-app-sms-tool-js) | 提供基于 JavaScript 的轻量化 Web 端短信收发与管理界面 |
| **luci-app-3ginfo-lite** | [4IceG/luci-app-3ginfo-lite](https://github.com/4IceG/luci-app-3ginfo-lite) | 提供蜂窝网络基站小区（PCI）、RSRP、SINR 实时信号看板 |
| **luci-theme-argon** | [jerrykuku/luci-theme-argon](https://github.com/jerrykuku/luci-theme-argon) | 提供现代化 Material Design 视觉主题与深色模式支持 |

> 特别感谢 **OpenWrt** / **Linux MediaTek Filogic** 开源社区的长期技术积累与驱动支持。
