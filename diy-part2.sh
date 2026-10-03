#!/bin/bash
cd openwrt

# 1. 自动覆盖自定义 DTS 设备树文件
if [ -f "$GITHUB_WORKSPACE/mt7981b-nradio-c8-668gl.dts" ]; then
    echo "Found custom DTS: mt7981b-nradio-c8-668gl.dts, overwriting target..."
    cp -f "$GITHUB_WORKSPACE/mt7981b-nradio-c8-668gl.dts" target/linux/mediatek/dts/mt7981b-nradio-c8-668gl.dts
elif [ -f "$GITHUB_WORKSPACE/c8-688.dts" ]; then
    echo "Found custom DTS: c8-688.dts, overwriting target..."
    cp -f "$GITHUB_WORKSPACE/c8-688.dts" target/linux/mediatek/dts/mt7981b-nradio-c8-668gl.dts
fi

# 2. 策略 B 关键适配：调整内核引导参数，让启动自动寻址 rootfs_2nd
sed -i 's/root=PARTLABEL=rootfs/root=PARTLABEL=rootfs_2nd/g' target/linux/mediatek/dts/mt7981* 2>/dev/null || true

# 3. 锁定管理后台 IP 为 192.168.66.1
sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate

# 4. 【核心修复】全量抹除 kmod-usb2 依赖，防止 OpenWrt 25.x (Linux 6.12) apk 依赖校验失败中断
find package/ feeds/ -type f -name "Makefile" -exec sed -i 's/+kmod-usb2//g' {} + 2>/dev/null || true
find package/ feeds/ -type f -name "*.mk" -exec sed -i 's/+kmod-usb2//g' {} + 2>/dev/null || true
sed -i '/CONFIG_PACKAGE_kmod-usb2/d' .config 2>/dev/null || true

# 5. 默认主题设置为 Argon (iStoreOS 现代视觉风格)
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true

# 6. 预设时区为上海 (CST-8)
sed -i "s/'UTC'/'CST-8'\n\t\tset system.@system[-1].zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate

# 7. 预设开启 TCP BBR 拥塞控制
sed -i -e '$a net.core.default_qdisc=fq' -e '$a net.ipv4.tcp_congestion_control=bbr' package/base-files/files/etc/sysctl.conf

# 8. 绑定你的 GitHub 仓库用于后台一键 OTA 更新 (AA9skillz-BN/nradio-c8-688-25.x)
mkdir -p package/custom/luci-app-autoupdate/root/etc/uci-defaults
cat << 'EOF' > package/custom/luci-app-autoupdate/root/etc/uci-defaults/99-autoupdate
uci -q batch << EOU
set autoupdate.@main[0].github_user='AA9skillz-BN'
set autoupdate.@main[0].github_repo='nradio-c8-688-25.x'
commit autoupdate
EOU
exit 0
EOF

# 9. 注入当前固件构建版本号标识
CURRENT_VER=$(date +%Y.%m.%d)
echo "$CURRENT_VER" > package/base-files/files/etc/openwrt_version

# 10. 注入 MT5700M 蜂窝管理工具集 (测邻区/读速率/查5QI/锁小区)
mkdir -p package/base-files/files/usr/bin
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
        echo "正在解除频段与小区锁定，恢复自动驻网..."
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
