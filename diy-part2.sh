#!/bin/bash
# =================================================================
# DIY Script Part 2 (After Update feeds)
# Target: NRadio C8-688 (MediaTek MT7981B / Filogic 820)
# =================================================================

# 1. 修正默认 IP 为 192.168.66.1
sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate

# 2. 注入设备定义到 filogic.mk
FILOGIC_MK="target/linux/mediatek/image/filogic.mk"
if [ -f "$FILOGIC_MK" ]; then
    if ! grep -q "define Device/nradio_c8-688" "$FILOGIC_MK"; then
        echo "Injecting Device/nradio_c8-688 to filogic.mk..."
        cat << 'EOF' >> "$FILOGIC_MK"

define Device/nradio_c8-688
  DEVICE_VENDOR := NRadio
  DEVICE_MODEL := C8-688
  DEVICE_DTS := mt7981b-nradio-c8-688
  DEVICE_DTS_DIR := $(DTS_DIR)/mediatek
  SUPPORTED_DEVICES := nradio,c8-688
  UBIFS_OPTS := -m 2048 -e 124KiB -c 4096
  IMAGE_SIZE := 65536k
  IMAGES += sysupgrade.bin
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += nradio_c8-688
EOF
    fi
fi

# 3. 部署双系统升级与启动分区保护钩子
mkdir -p package/base-files/files/lib/upgrade
cat << 'EOF' > package/base-files/files/lib/upgrade/platform.sh
#!/bin/sh
RAMFS_COPY_BIN='fw_printenv fw_setenv'

platform_check_image() {
	return 0
}

platform_do_upgrade() {
	local diskdev="$(partx -s /dev/mmcblk0 2>/dev/null)"
	local rootfs_part="/dev/mmcblk0p9"
	local kernel_part="/dev/mmcblk0p8"

	echo "Upgrading ImmortalWrt on Slot B (rootfs_2nd)..."
	tar -xzOf "$1" sysupgrade-nradio_c8-688/kernel | dd of="$kernel_part" bs=4M conv=fsync 2>/dev/null
	tar -xzOf "$1" sysupgrade-nradio_c8-688/root | dd of="$rootfs_part" bs=4M conv=fsync 2>/dev/null

	# 确保 U-Boot 引导指向副系统 Slot B
	fw_setenv boot_system 1 2>/dev/null || true
	fw_setenv active_slot 1 2>/dev/null || true
	return 0
}
EOF
chmod +x package/base-files/files/lib/upgrade/platform.sh

# 4. 植入双系统切换命令行工具 (switch-system)
mkdir -p package/base-files/files/usr/sbin
cat << 'EOF' > package/base-files/files/usr/sbin/switch-system
#!/bin/sh

show_usage() {
    echo "=========================================="
    echo "       NRadio C8-688 双系统切换工具       "
    echo "=========================================="
    echo "用法: switch-system [a|b]"
    echo "  a : 切换为引导原厂主系统 (Slot A)"
    echo "  b : 切换为引导 ImmortalWrt 副系统 (Slot B)"
    echo "=========================================="
}

case "$1" in
    a|A)
        echo "[*] 正在设置 U-Boot 引导槽位为 系统 A (原厂)..."
        fw_setenv boot_system 0 2>/dev/null || true
        fw_setenv active_slot 0 2>/dev/null || true
        fw_setenv boot_slot a 2>/dev/null || true
        echo "[+] 设置完成！输入 reboot 重启即可进入原厂系统。"
        ;;
    b|B)
        echo "[*] 正在设置 U-Boot 引导槽位为 系统 B (ImmortalWrt)..."
        fw_setenv boot_system 1 2>/dev/null || true
        fw_setenv active_slot 1 2>/dev/null || true
        fw_setenv boot_slot b 2>/dev/null || true
        echo "[+] 设置完成！输入 reboot 重启即可进入副系统。"
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
EOF
chmod +x package/base-files/files/usr/sbin/switch-system

# 5. 5G 模块 (MT5700M / T750) 锁频锁网工具 (cpe-tool)
cat << 'EOF' > package/base-files/files/usr/sbin/cpe-tool
#!/bin/sh
TTY_DEV=""
for dev in /dev/ttyUSB1 /dev/ttyUSB2 /dev/ttyUSB0 /dev/cdc-wdm0; do
    if [ -e "$dev" ]; then
        TTY_DEV="$dev"
        break
    fi
done

if [ -z "$TTY_DEV" ]; then
    echo "[-] 错误: 未检测到 5G 模块 AT 控制端口！"
    exit 1
fi

send_at() {
    local cmd="$1"
    echo -e "${cmd}\r\n" > "$TTY_DEV"
    timeout 2 cat "$TTY_DEV" | tr -d '\r'
}

case "$1" in
    info)
        echo "=== 模组型号与固件版本 ==="
        send_at "ATI"
        echo "=== 信号质量 (CSQ) ==="
        send_at "AT+CSQ"
        ;;
    sim)
        echo "=== SIM 卡就绪检测 ==="
        send_at "AT+CPIN?"
        ;;
    band)
        echo "=== 当前驻网频段与小区信息 ==="
        send_at "AT+CEREG?"
        ;;
    send)
        [ -n "$2" ] && send_at "$2" || echo "用法: cpe-tool send \"AT命令\""
        ;;
    *)
        echo "NRadio C8-688 5G 控制工具"
        echo "用法: cpe-tool [info|sim|band|send <CMD>]"
        ;;
esac
EOF
chmod +x package/base-files/files/usr/sbin/cpe-tool

# 6. 配置满血 Wi-Fi 6 (160MHz、信道 36、免密)
mkdir -p package/base-files/files/etc/uci-defaults
cat << 'EOF' > package/base-files/files/etc/uci-defaults/98-fullpower-wifi
#!/bin/sh
[ ! -f /etc/config/wireless ] && wifi config

dev_2g=""
dev_5g=""

for dev in $(uci show wireless | grep "=wifi-device" | cut -d'.' -f2 | cut -d'=' -f1); do
    band=$(uci -q get wireless.${dev}.band)
    channel=$(uci -q get wireless.${dev}.channel)
    htmode=$(uci -q get wireless.${dev}.htmode)

    if [ "$band" = "5g" ] || [ "$channel" -gt 14 ] 2>/dev/null || echo "$htmode" | grep -qi "HE80\|HE160"; then
        dev_5g="$dev"
    else
        dev_2g="$dev"
    fi
done

[ -z "$dev_5g" ] && dev_5g="radio0"
[ -z "$dev_2g" ] && dev_2g="radio1"

# 5GHz 配置
uci set wireless.${dev_5g}.disabled='0'
uci set wireless.${dev_5g}.band='5g'
uci set wireless.${dev_5g}.channel='36'
uci set wireless.${dev_5g}.htmode='HE160'
uci set wireless.${dev_5g}.country='CN'

# 2.4GHz 配置
uci set wireless.${dev_2g}.disabled='0'
uci set wireless.${dev_2g}.band='2g'
uci set wireless.${dev_2g}.channel='auto'
uci set wireless.${dev_2g}.htmode='HE40'
uci set wireless.${dev_2g}.country='CN'

# 默认 SSID
if uci get wireless.default_${dev_5g} >/dev/null 2>&1; then
    uci set wireless.default_${dev_5g}.ssid='NRadio-C8-688-5G'
    uci set wireless.default_${dev_5g}.encryption='none'
fi

if uci get wireless.default_${dev_2g} >/dev/null 2>&1; then
    uci set wireless.default_${dev_2g}.ssid='NRadio-C8-688-2.4G'
    uci set wireless.default_${dev_2g}.encryption='none'
fi

uci commit wireless
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/98-fullpower-wifi

# 7. 开启硬件 PPE 流控与基础网络调优
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-network-tweaks
#!/bin/sh
uci set firewall.@defaults[0].flow_offloading='1'
uci set firewall.@defaults[0].flow_offloading_hw='1'
uci commit firewall

# 调整最大连接数与内核 TCP 缓冲
sysctl -w net.netfilter.nf_conntrack_max=131072 2>/dev/null
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-network-tweaks

# 8. 清理废弃的 kmod-usb2 强依赖，确保 apk 打包通畅
find package/ feeds/ -name "Makefile" -o -name "*.mk" | xargs sed -i 's/+kmod-usb2//g' 2>/dev/null || true

# 9. 自动检测并覆盖源码中的 DTS
find target/linux/mediatek/dts/ -name "*mt7981*.dts*" | head -n 1 > /tmp/dts_path
DTS_DIR="target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek"
[ ! -d "$DTS_DIR" ] && DTS_DIR="target/linux/mediatek/files-6.6/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DIR"
for src_dts in "$GITHUB_WORKSPACE"/mt7981b-nradio-c8-688.dts ./mt7981b-nradio-c8-688.dts; do
    if [ -f "$src_dts" ]; then
        echo "Found custom DTS at: $src_dts -> copying to $DTS_DIR"
        cp -f "$src_dts" "$DTS_DIR/mt7981b-nradio-c8-688.dts"
        break
    fi
done

# 10. 设置系统时区与中文语言
cat << 'EOF' > package/base-files/files/etc/uci-defaults/97-system-init
#!/bin/sh
uci set system.@system[0].zonename='Asia/Shanghai'
uci set system.@system[0].timezone='CST-8'
uci commit system
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/97-system-init

# 11. 绑定一键在线 OTA 升级源
mkdir -p package/base-files/files/etc/autoupdate
cat << 'EOF' > package/base-files/files/etc/autoupdate/github.conf
github_user="AA9skillz-BN"
github_repo="nradio-c8-688-25.x"
firmware_tag="immortalwrt-mediatek-filogic-nradio_c8-688-squashfs-sysupgrade.bin"
EOF

# 12. 注入 LuCI 图形化双系统切换页面
LUCI_DUALBOOT_DIR="package/base-files/files/usr/lib/lua/luci"
mkdir -p "$LUCI_DUALBOOT_DIR/controller"
mkdir -p "$LUCI_DUALBOOT_DIR/view/dualboot"

cat << 'EOF' > "$LUCI_DUALBOOT_DIR/controller/dualboot.lua"
module("luci.controller.dualboot", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/system") then
        return
    end
    entry({"admin", "system", "dualboot"}, template("dualboot/index"), _("双系统切换"), 90).dependent = true
    entry({"admin", "system", "dualboot", "switch"}, call("action_switch")).leaf = true
end

function action_switch()
    local http = require "luci.http"
    local slot = http.formvalue("slot")
    
    if slot == "a" or slot == "b" then
        os.execute("/usr/sbin/switch-system " .. slot)
        http.prepare_content("application/json")
        http.write_json({ status = "ok", target = slot })
        os.execute("sleep 2 && reboot &")
    else
        http.prepare_content("application/json")
        http.write_json({ status = "error", message = "Invalid slot" })
    end
end
EOF

cat << 'EOF' > "$LUCI_DUALBOOT_DIR/view/dualboot/index.htm"
<%+header%>
<div class="cbi-map">
    <h2 name="content"><%:NRadio C8-688 双系统槽位切换%></h2>
    <div class="cbi-map-descr">
        <%:当前设备支持 A/B 双系统安全引导。在此页面点击即可无损切换引导槽位，点击后路由器将自动保存 U-Boot 引导参数并重启。%>
    </div>

    <div class="cbi-section">
        <legend><%:槽位操作%></legend>
        <div class="cbi-section-node">
            <table class="cbi-section-table" style="width: 100%; text-align: left;">
                <tr class="cbi-section-table-row">
                    <td style="padding: 15px; width: 60%;">
                        <strong><%:原厂主系统 (Slot A)%></strong><br />
                        <span style="color: #666;"><%:位于 mmcblk0p6 (kernel) 与 mmcblk0p7 (rootfs)，为出厂官方系统。%></span>
                    </td>
                    <td style="padding: 15px;">
                        <button class="cbi-button cbi-button-reset" onclick="doSwitch('a')"><%:切回原厂主系统 A%></button>
                    </td>
                </tr>
                <tr class="cbi-section-table-row">
                    <td style="padding: 15px; width: 60%;">
                        <strong><%:ImmortalWrt 副系统 (Slot B)%></strong><br />
                        <span style="color: #666;"><%:位于 mmcblk0p8 (kernel_2nd) 与 mmcblk0p9 (rootfs_2nd)，即当前系统。%></span>
                    </td>
                    <td style="padding: 15px;">
                        <button class="cbi-button cbi-button-apply" onclick="doSwitch('b')"><%:重启进入副系统 B%></button>
                    </td>
                </tr>
            </table>
        </div>
    </div>
</div>

<script type="text/javascript">
function doSwitch(slot) {
    var slotName = (slot === 'a') ? '<%:原厂主系统 A%>' : '<%:ImmortalWrt 副系统 B%>';
    if (!confirm('<%:确定要切换并立即重启进入 %> ' + slotName + ' <%: 吗？%>')) {
        return;
    }
    
    var btn = event.target;
    btn.disabled = true;
    btn.innerText = '<%:正在切换并准备重启...%>';

    (new XHR()).post('<%=url("admin/system/dualboot/switch")%>', { slot: slot }, function(x, info) {
        if (info && info.status === 'ok') {
            alert('<%:引导已切换为 %> ' + slotName + '！<%: 路由器正在重启，约 60 秒后可尝试重新连接。%>');
        } else {
            alert('<%:切换失败，请检查系统日志。%>');
            btn.disabled = false;
        }
    });
}
</script>
<%+footer%>
EOF

# 13. 集成 FAN789 图形化 5G CPE 风扇控制插件并适配 C8-688 硬件
rm -rf package/luci-app-h5000m-fancontrol
git clone --depth 1 https://github.com/FAN789/luci-app-h5000m-fancontrol.git package/luci-app-h5000m-fancontrol

FAN_PKG="package/luci-app-h5000m-fancontrol"
if [ -d "$FAN_PKG" ]; then
    echo "Patching luci-app-h5000m-fancontrol for C8-688 hardware..."
    find "$FAN_PKG" -type f \( -name "*.sh" -o -name "*.lua" -o -name "fancontrol" \) | xargs sed -i 's/\/sys\/devices\/platform\/10048000.pwm\/pwm\/pwmchip0/\/sys\/devices\/platform\/pwm-fan\/hwmon\/hwmon0/g' 2>/dev/null || true
    find "$FAN_PKG" -type f \( -name "*.sh" -o -name "*.lua" -o -name "fancontrol" \) | xargs sed -i 's/pwm0/pwm1/g' 2>/dev/null || true
    find "$FAN_PKG" -type f -name "*fan*.sh" | while read -r f; do
        sed -i '/echo.*>.*pwm/i \    [ -f /sys/class/gpio/fan-hw/value ] && echo 1 > /sys/class/gpio/fan-hw/value 2>/dev/null' "$f" 2>/dev/null || true
    done
fi

# 14. 集成 MT5700M 专属 5G 模组 WebUI 控制面板并适配 C8-688 硬件
rm -rf package/luci-app-mt5700m package/luci-app-mt5700
if ! git clone --depth 1 https://github.com/FAN789/luci-app-mt5700m.git package/luci-app-mt5700m 2>/dev/null; then
    git clone --depth 1 https://github.com/LianXia233/luci-app-mt5700.git package/luci-app-mt5700m 2>/dev/null || true
fi

MT5700_PKG="package/luci-app-mt5700m"
if [ -d "$MT5700_PKG" ]; then
    echo "Configuring MT5700M WebUI for C8-688..."
    find "$MT5700_PKG" -type f \( -name "*.lua" -o -name "*.sh" -o -name "*config*" \) | while read -r f; do
        sed -i 's/\/dev\/ttyUSB2/\/dev\/ttyUSB1/g' "$f" 2>/dev/null || true
    done
fi

# 15. 创建顶层“蜂窝网络”大分类，仅收纳 MT5700M 模组面板
mkdir -p package/base-files/files/usr/lib/lua/luci/controller
cat << 'EOF' > package/base-files/files/usr/lib/lua/luci/controller/cellular.lua
module("luci.controller.cellular", package.seeall)

function index()
    -- 创建一级顶级菜单分类：蜂窝网络 (排序权重 25，位于状态概况之后)
    entry({"admin", "cellular"}, firstchild(), _("蜂窝网络"), 25).dependent = false
end
EOF

# 仅将 MT5700M WebUI 重定向至“蜂窝网络”大分类下
MT5700_PKG="package/luci-app-mt5700m"
if [ -d "$MT5700_PKG" ]; then
    echo "Relocating MT5700M to Cellular category..."
    find "$MT5700_PKG" -type f -name "*.lua" | while read -r f; do
        sed -i 's/entry({"admin", "modem"/entry({"admin", "cellular"/g' "$f" 2>/dev/null || true
        sed -i 's/entry({"admin", "network", "mt5700m"/entry({"admin", "cellular", "mt5700m"/g' "$f" 2>/dev/null || true
        sed -i 's/entry({"admin", "network", "mt5700"/entry({"admin", "cellular", "mt5700"/g' "$f" 2>/dev/null || true
    done
fi

exit 0
