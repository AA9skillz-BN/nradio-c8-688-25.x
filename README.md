# 🚀 NRadio C8-688 ImmortalWrt DualBoot 固件

专为 NRadio C8-688 (MT7981B + 1GB RAM + 8GB eMMC) 打造的满血极速、双系统无损共存固件。

---

## 🌟 核心特性亮点

- 🧠 **1GB RAM 满血激活**：内核 DTS 物理内存重构（`0x40000000 - 0x80000000`），告别 512MB 限制，高并发与插件多开无压力。
- 🛡️ **A/B 双系统无损隔离**：
  - **Slot A**：原厂出厂系统，物理锁死永不冲刷。
  - **Slot B**：ImmortalWrt 专属副系统，支持 WebUI 一键无损平滑切换。
- 📶 **「蜂窝网络」独立顶级大分类**：深度集成 MT5700M 5G 控制面板，支持 5G 信号看板、锁频（Band Lock）、锁基站、SA/NSA 切换及网页端 AT 终端交互，自动绑定串口 `/dev/ttyUSB1`。
- 💾 **8GB eMMC 自动撑满**：首次开机自适应扩展底层物理扇区，`/overlay` 分区自动拉满释放 6GB+ 真实可用空间。
- ❄️ **硬件 PWM 智能温控**：驱动 MT7981B 芯片原生 PWM，集成 H5000M 智能温控风扇面板，支持自适应调速与全速散热。
- ⚡ **Turbo ACC 深度加速**：开启 MTK 硬件 PPE 芯片转发加速、FullCone NAT、内核级 BBR 拥塞控制。
- 🔄 **GitHub Release 一键在线更新**：后台点选一键检测版本并静默升级，升级时严格拦截并烧入 Slot B 分区。

---

## 🖥️️ 默认设备参数

| 参数项 | 默认配置信息 |
| :--- | :--- |
| **后台地址** | `192.168.66.1` |
| **默认账号** | `root` |
| **默认密码** | `password` 或空（无密码） |
| **默认主题** | Argon（自适应深色/浅色模式） |
| **副系统槽位** | Slot B（内核: `/dev/mmcblk0p8`，根文件系统: `/dev/mmcblk0p9`） |

---

## 🧭 后台 Web 菜单层次架构

- 📊 **状态 (Status)**
- 📶 **蜂窝网络 (Cellular)**：5G 模组管理 (MT5700M) / 锁频锁基站 / 网页 AT 控制台
- ⚙️ **服务 (Services)**：CPE 智能温控风扇管理 (H5000M)
- 🌐 **网络 (Network)**：接口 / 无线 / Turbo ACC 网络加速
- 💻 **系统 (System)**：
  - 🔄 **双系统切换 (DualBoot)**：一键在 Slot A 原厂与 Slot B 之间切换引导
  - 🚀 **在线更新 (AutoUpdate)**：一键检测 GitHub Release 最新版本并静默刷入
  - 🎨 **Argon 配置**：登录壁纸与外观定制
 
---

## 🤝 致谢与鸣谢
ImmortalWrt Project

**FAN789/luci-app-mt5700m**

**FAN789/luci-app-h5000m-fancontrol**

**Hyy2001X/luci-app-autoupdate**

**jerrykuku/luci-theme-argon**
