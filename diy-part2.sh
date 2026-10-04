#!/bin/bash
# --------------------------------------------------------
# DIY script 2: NRadio C8-688 满血性能与双系统锁定注入
# --------------------------------------------------------

cd openwrt || true

# 1. 动态注入 nradio_c8-688 到 filogic.mk 并规范设备名
TARGET_MK="target/linux/mediatek/image/filogic.mk"
if [ -f "$TARGET_MK" ]; then
    sed -i 's/nradio_c8-668gl/nradio_c8-688/g' "$TARGET_MK"
    sed -i 's/mt7981b-nradio-c8-668gl/mt7981b-nradio-c8-688/g' "$TARGET_MK"
    sed -i 's/C8-668GL/C8-688/g' "$TARGET_MK"
    
    if ! grep -q "Device/nradio_c8-688" "$TARGET_MK"; then
        cat << 'EOF' >> "$TARGET_MK"

define Device/nradio_c8-688
  DEVICE_VENDOR := NRadio
  DEVICE_MODEL := C8-688
  DEVICE_DTS := mt7981b-nradio-c8-688
  DEVICE_DTS_DIR := $(DTS_DIR)/mediatek
  SUPPORTED_DEVICES := nradio,c8-688
  UBINIZE_OPTS := -E 5
  IMAGE_SIZE := 65536k
  IMAGES += sysupgrade.bin
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += nradio_c8-688
EOF
    fi
fi

# 2. 覆盖自定义 DTS 并修复 Linux 6.12 命名与分区挂载
DTS_TARGET="target/linux/mediatek/dts/mt7981b-nradio-c8-688.dts"
mkdir -p target/linux/mediatek/dts target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek

for DTS_SRC in "$GITHUB_WORKSPACE/mt7981b-nradio-c8-688.dts" "$GITHUB_WORKSPACE/mt7981b-nradio-c8-668gl.dts" "$GITHUB_WORKSPACE/c8-688.dts"; do
    if [ -f "$DTS_SRC" ]; then
        echo "Found custom DTS: $DTS_SRC, overwriting target..."
        cp -f "$DTS_SRC" "$DTS_TARGET"
        cp -f "$DTS_SRC" "target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek/mt7981b-nradio-c8-688.dts" 2>/dev/null || true
        break
    fi
done

# 根治 mt7981.dtsi 缺失并锁定副系统 rootfs_2nd
find target/linux/mediatek/ -name "*.dts*" | while read -r dts_file; do
    sed -i 's/\r$//' "$dts_file"
    sed -i 's/"mt7981\.dtsi"/"mt7981b\.dtsi"/g' "$dts_file"
    if grep -q "root=PARTLABEL=rootfs" "$dts_file"; then
        sed -i 's/root=PARTLABEL=rootfs/root=PARTLABEL=rootfs_2nd/g' "$dts_file"
    fi
done

# 3. 【核心双系统适配】Hook sysupgrade 升级逻辑，防止一键升级覆盖主系统
mkdir -p package/base-files/files/etc/uci-defaults
cat << 'EOF' > package/base-files/files/etc/uci-defaults/90-dualboot-protect
#!/bin/sh
if [ -f /lib/upgrade/platform.sh ]; then
    sed -i 's/PARTLABEL=rootfs/PARTLABEL=rootfs_2nd/g' /lib/upgrade/platform.sh 2>/dev/null || true
    sed -i 's/PARTLABEL=kernel/PARTLABEL=kernel_2nd/g' /lib/upgrade/platform.sh 2>/dev/null || true
fi
exit 0
EOF

# 4. 注入双系统槽位快速切换工具
mkdir -p package/base-files/files/usr/bin
cat << 'EOF' > package/base-files/files/usr/bin/switch-system
#!/bin/sh
case "$1" in
    a|A|primary)
        echo "正在切换下一启动槽位为: 系统 A (原厂主系统)..."
        fw_setenv boot_system 0 2>/dev/null || fw_setenv active_slot 0 2>/dev/null || echo "请通过 U-Boot 确认变量名"
        echo "设置完成，重启后生效。"
        ;;
    b|B|secondary)
        echo "正在确认下一启动槽位为: 系统 B (ImmortalWrt 副系统)..."
        fw_setenv boot_system 1 2>/dev/null || fw_setenv active_slot 1 2>/dev/null || echo "请通过 U-Boot 确认变量名"
        echo "设置完成，重启后生效。"
        ;;
    *)
        echo "双系统槽位切换工具:"
        echo "  switch-system a  - 下次重启进入系统 A (原厂主系统)"
        echo "  switch-system b  - 下次重启进入系统 B (当前副系统)"
        ;;
esac
EOF
chmod +x package/base-files/files/usr/bin/switch-system

# 5. 锁定管理后台 IP 为 192.168.66.1
sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate

# 6. 【满血 Wi-Fi 射频调优】预设 160MHz、满血功率、专属 SSID
cat << 'EOF' > package/base-files/files/etc/uci-defaults/98-fullpower-wifi
#!/bin/sh
# 强制生成初始无线配置（如果尚未生成）
[ ! -f /etc/config/wireless ] && wifi config

for radio in $(uci -q show wireless | grep '=wifi-device' | cut -d'.' -f2 | cut -d'=' -f1); do
    uci -q set wireless.${radio}.disabled='0'
    uci -q set wireless.${radio}.country='CN'
    
    band=$(uci -q get wireless.${radio}.band 2>/dev/null || echo "")
    htmode=$(uci -q get wireless.${radio}.htmode 2>/dev/null || echo "")
    iface=$(uci -q show wireless | grep "device='${radio}'" | cut -d'.' -f2 | head -n 1)

    if [ "$band" = "5g" ] || [ "$band" = "6g" ] || echo "$htmode" | grep -q "HE80\|HE160\|VHT80"; then
        uci -q set wireless.${radio}.channel='36'
        uci -q set wireless.${radio}.htmode='HE160'
        if [ -n "$iface" ]; then
            uci -q set wireless.${iface}.ssid='NRadio-C8-688-5G'
            uci -q set wireless.${iface}.encryption='none'
        fi
    else
        uci -q set wireless.${radio}.channel='auto'
        uci -q set wireless.${radio}.htmode='HE40'
        if [ -n "$iface" ]; then
            uci -q set wireless.${iface}.ssid='NRadio-C8-688-2.4G'
            uci -q set wireless.${iface}.encryption='none'
        fi
    fi
done

# 兼容 MTK 原厂无线驱动文件
if [ -f /etc/config/wireless ]; then
    sed -i 's/SSID1=.*$/SSID1=NRadio-C8-688-2.4G/g' /etc/config/wireless 2>/dev/null || true
    sed -i 's/SSID2=.*$/SSID2=NRadio-C8-688-5G/g' /etc/config/wireless 2>/dev/null || true
    sed -i 's/HtBw=.*$/HtBw=1/g' /etc/config/wireless 2>/dev/null || true
    sed -i 's/VhtBw=.*$/VhtBw=2/g' /etc/config/wireless 2>/dev/null || true
fi

uci commit wireless
wifi reload 2>/dev/null || true
exit 0
EOF

# 7. 【满血网络加速预设】PPE 硬件转发 + FullCone + BBR 拥塞控制
cat << 'EOF' > package/base-files/files/etc/uci-defaults/95-turboacc-default
#!/bin/sh
uci -q batch << EOU
set turboacc.config.sw_flow='0'
set turboacc.config.hw_flow='1'
set turboacc.config.fullcone_nat='1'
set turboacc.config.bbr_cca='1'
commit turboacc
EOU
exit 0
EOF

# 8. 【满血网络栈与 5G 缓冲区调优】
cat << 'EOF' >> package/base-files/files/etc/sysctl.conf
# 核心队列与拥塞控制
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# 提升 5G 高吞吐发包队列深度
net.core.netdev_max_backlog=16384
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
EOF

# 9. 清理 kmod-usb2 避免构建校验阻断
find package/ feeds/ -type f -name "Makefile" -exec sed -i 's/+kmod-usb2//g' {} + 2>/dev/null || true
find package/ feeds/ -type f -name "*.mk" -exec sed -i 's/+kmod-usb2//g' {} + 2>/dev/null || true
sed -i '/CONFIG_PACKAGE_kmod-usb2/d' .config 2>/dev/null || true

# 10. 默认主题 Argon 与时区设置
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true
sed -i "s/'UTC'/'CST-8'\n\t\tset system.@system[-1].zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate

# 11. 绑定 GitHub 仓库在线 OTA
mkdir -p package/custom/luci-app-autoupdate/root/etc/uci-defaults
cat << 'EOF' > package/custom/luci-app-autoupdate/root/etc/uci-defaults/99-autoupdate
uci -q batch << EOU
set autoupdate.@main[0].github_user='AA9skillz-BN'
set autoupdate.@main[0].github_repo='nradio-c8-688-25.x'
commit autoupdate
EOU
exit 0
EOF

CURRENT_VER=$(date +%Y.%m.%d)
echo "$CURRENT_VER" > package/base-files/files/etc/openwrt_version

# 12. 注入 MT5700M 5G 诊断与锁网工具 cpe-tool
cat << 'EOF' > package/base-files/files/usr/bin/cpe-tool
#!/bin/sh
PORT=$(ls /dev/ttyUSB* /dev/cdc-wdm* 2>/dev/null | grep -E 'USB1|USB2|wdm0' | head -n 1)
[ -z "$PORT" ] && echo "错误: 未找到 MT5700M 的 AT 控制端口！" && exit 1

send_at() {
    chat -t 3 -e '' "$1" 'OK' '' >/dev/null <"$PORT" 2>&1
}

case "$1" in
    neighbor|cell)
        echo "=== 正在扫描当前服务小区及周围邻区列表 (Neighbor Cells) ==="
        send_at 'AT^MONSC'
        send_at 'AT^MONNC'
        ;;
    qos|speed)
        echo "=== 正在读取当前 PDP 承载信息与签约速率 (AMBR) ==="
        send_at 'AT+CGCONTRDP=1'
        echo "=== 正在读取 5G 5QI / 4G QCI 服务等级 ==="
        send_at 'AT+C5GQOSRDP=1' 2>/dev/null || send_at 'AT+CGEQOSRDP=1'
        ;;
    lock-pci)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "用法: cpe-tool lock-pci <频点> <小区PCI>"
            echo "示例: cpe-tool lock-pci 630000 128"
            exit 1
        fi
        echo "正在锁定频点 $2, 小区 PCI $3 ..."
        send_at "AT^FREQLOCK=1,$2,$3"
        ;;
    unlock)
        echo "正在解除频段与小区锁定，恢复自动搜网..."
        send_at 'AT^FREQLOCK=0'
        ;;
    *)
        echo "C8-688 CPE 管理诊断命令:"
        echo "  cpe-tool neighbor   - 扫描并查看周围邻区列表"
        echo "  cpe-tool qos        - 查看当前 QCI/5QI 等级和运营商签约上下行限速"
        echo "  cpe-tool lock-pci   - 锁定指定频点和小区 PCI"
        echo "  cpe-tool unlock     - 解锁所有频段/小区，恢复自动搜网"
        ;;
esac
EOF
chmod +x package/base-files/files/usr/bin/cpe-tool
