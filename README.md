NRadio C8-688 ImmortalWrt DualBoot 固件
专为 NRadio C8-688 (MT7981B + 1GB RAM + 8GB eMMC) 打造的满血极速、双系统无损共存固件。
🌟 核心特性亮点
* 1GB RAM 满血激活：内核 DTS 物理内存重构（0x40000000 - 0x80000000），告别 512MB 限制，高并发与插件多开无压力。
* A/B 双系统无损隔离：
   * Slot A：原厂出厂系统，物理锁死永不冲刷。
   * Slot B：ImmortalWrt 专属副系统，支持 WebUI 一键无损平滑切换。
* 「蜂窝网络」独立顶级大分类：深度集成 MT5700M 5G 控制面板，支持 5G 信号看板、锁频（Band Lock）、锁基站、SA/NSA 切换及网页端 AT 终端交互，自动绑定串口 /dev/ttyUSB1。
* 8GB eMMC 自动撑满：首次开机自适应扩展底层物理扇区，/overlay 分区自动拉满释放 6GB+ 真实可用空间。
* 硬件 PWM 智能温控：驱动 MT7981B 芯片原生 PWM，集成 H5000M 智能温控风扇面板，支持自适应调速与全速散热。
* Turbo ACC 深度加速：开启 MTK 硬件 PPE 芯片转发加速、FullCone NAT、内核级 BBR 拥塞控制。
* GitHub Release 一键在线更新：后台点选一键检测版本并静默升级，升级时严格拦截并烧入 Slot B 分区。
🖥️ 默认设备参数
参数项
	默认配置信息
	后台地址
	192.168.66.1
	默认账号
	root
	默认密码
	password 或空（无密码）
	默认主题
	Argon（自适应深色/浅色模式）
	副系统槽位
	Slot B（内核: /dev/mmcblk0p8，根文件系统: /dev/mmcblk0p9）
	🧭 后台 Web 菜单层次架构
* 状态 (Status)
* 蜂窝网络 (Cellular)：5G 模组管理 (MT5700M) / 锁频锁基站 / 网页 AT 控制台
* 服务 (Services)：CPE 智能温控风扇管理 (H5000M)
* 网络 (Network)：接口 / 无线 / Turbo ACC 网络加速
* 系统 (System)：
   * 双系统切换 (DualBoot)：一键在 Slot A 原厂与 Slot B 之间切换引导
   * 在线更新 (AutoUpdate)：一键检测 GitHub Release 最新版本并静默刷入
   * Argon 配置：登录壁纸与外观定制
🛠️ 初次刷入指南 (从原厂系统刷入副系统)
1. 下载并上传固件
从 Releases 页面下载最新的 immortalwrt-mediatek-filogic-nradio_c8-688-squashfs-sysupgrade.bin 固件包，通过 SCP 上传至设备的 /tmp 目录：


scp immortalwrt-*-sysupgrade.bin root@192.168.66.1:/tmp/sysupgrade.bin
2. SSH 终端执行精准刷写
连接路由器终端并执行写入命令：


ssh root@192.168.66.1cd /tmp
tar -xf sysupgrade.bin


# 写入内核到 mmcblk0p8 (Slot B 内核物理分区)
dd if=$(find sysupgrade-*/ -name "kernel") of=/dev/mmcblk0p8 bs=4M conv=fsync


# 写入根文件系统到 mmcblk0p9 (Slot B 根系统物理分区)
dd if=$(find sysupgrade-*/ -name "rootfs") of=/dev/mmcblk0p9 bs=4M conv=fsync


# 切换 U-Boot 启动引导至副系统 (Slot B)
fw_setenv boot_part 2


# 同步磁盘并重启生效
sync && reboot
3. 开机验证存储空间
重启后登录新系统后台 (192.168.66.1)，在终端执行空间检查：


df -h /overlay若显示 /overlay 可用空间达到 5.5G - 6.5G 左右，说明 8GB eMMC 空间已自适应扩容完成！
🔄 后续日常升级
1. 登录 LuCI 管理后台，点击「系统」->「在线更新」。
2. 点击「检查更新」，系统自动对比 GitHub Releases 中的最新构建版本。
3. 点击「一键更新」，固件自动下载并安全烧入 Slot B 副系统，重启即用。


🤝 致谢与鸣谢
* ImmortalWrt Project
* FAN789/luci-app-mt5700m
* FAN789/luci-app-h5000m-fancontrol
* Hyy2001X/luci-app-autoupdate
* jerrykuku/luci-theme-argon