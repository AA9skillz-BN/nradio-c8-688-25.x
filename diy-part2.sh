#!/bin/bash
# -----------------------------------------------------------------------------
# DIY script 2: Executed after feeds update & install, before make defconfig
# 全面适配 25.x / master 分支
# -----------------------------------------------------------------------------

[ -d "openwrt" ] && cd openwrt

# 1. 注册 nradio_c8-688 编译目标与 1GB RAM 设备树 (DTS)
FILOGIC_MK="target/linux/mediatek/image/filogic.mk"

# 动态定位 upstream c8-668 设备树
SRC_668_DTS=$(find target/linux/mediatek/ -name "*c8-668*.dts*" | head -n 1)

if [ -n "$SRC_668_DTS" ] && [ -f "$SRC_668_DTS" ]; then
    TARGET_DTS_DIR="$(dirname "$SRC_668_DTS")"
    echo "Found upstream C8-668 DTS at: $SRC_668_DTS"
    cp -f "$SRC_668_DTS" "$TARGET_DTS_DIR/mt7981b-nradio-c8-688.dts"
    # 将 512MB 物理内存扩充为 1GB (0x40000000 长度)
    sed -i 's/<0x40000000 0x20000000>/<0x40000000 0x40000000>/g' "$TARGET_DTS_DIR/mt7981b-nradio-c8-688.dts"
    sed -i 's/c8-668/c8-688/g' "$TARGET_DTS_DIR/mt7981b-nradio-c8-688.dts"
fi

if [ -f "$FILOGIC_MK" ] && ! grep -q "nradio_c8-688" "$FILOGIC_MK"; then
    echo "Injecting Device/nradio_c8-688 into filogic.mk..."
    cat << 'EOF' >> "$FILOGIC_MK"

define Device/nradio_c8-688
  DEVICE_VENDOR := NRadio
  DEVICE_MODEL := C8-688
  DEVICE_DTS := mt7981b-nradio-c8-688
  DEVICE_DTS_DIR := $(DTS_DIR)/mediatek
  SUPPORTED_DEVICES := nradio,c8-688 nradio,c8-668
  DEVICE_PACKAGES := kmod-mt7981-firmware kmod-usb-net-cdc-ether kmod-usb-net-rndis kmod-usb-serial-option
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += nradio_c8-688
EOF
fi

# 2. 修改默认 LAN IP 为 192.168.66.1
sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate

# 3. 清理已废弃的 kmod-usb2 依赖
find package/ feeds/ -name "Makefile" -o -name "*.mk" | xargs sed -i 's/+kmod-usb2//g' 2>/dev/null || true

# 4. 创建系统底层目录
mkdir -p package/base-files/files/etc/uci-defaults
mkdir -p package/base-files/files/lib/upgrade
mkdir -p package/base-files/files/usr/lib/lua/luci/controller

# 5. 首次开机自适应扩展 8GB eMMC 分区空间 (/overlay 撑满)
cat << 'EOF' > package/base-files/files/etc/uci-defaults/96-expand-overlay
#!/bin/sh
if [ ! -f /etc/expanded_overlay_done ]; then
    partx -u /dev/mmcblk0 2>/dev/null || true
    resize.f2fs /dev/mmcblk0p9 2>/dev/null || true
    touch /etc/expanded_overlay_done
fi
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/96-expand-overlay

# 6. 配置 AutoUpdate 绑定当前仓库
cat << 'EOF' > package/base-files/files/etc/uci-defaults/97-autoupdate-custom
#!/bin/sh
uci -q batch << EOU
set autoupdate.main=autoupdate
set autoupdate.main.github='AA9skillz-BN/nradio-c8-688-25.x'
set autoupdate.main.cloud='GitHub'
commit autoupdate
EOU
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/97-autoupdate-custom

# 7. 升级脚本：锁死写入 Slot B (mmcblk0p8 / mmcblk0p9)
cat << 'EOF' > package/base-files/files/lib/upgrade/platform.sh
#!/bin/sh
RAMFS_COPY_BIN="${RAMFS_COPY_BIN} /usr/sbin/fw_printenv /usr/sbin/fw_setenv"

platform_check_image() {
    return 0
}

platform_do_upgrade() {
    local tar_file="$1"
    local board_dir=$(tar -tf "$tar_file" | grep -m 1 '^sysupgrade-.*/$')
    board_dir="${board_dir%/}"

    echo "=== Upgrading Slot B (mmcblk0p8 & mmcblk0p9) ==="
    tar -xf "$tar_file" "${board_dir}/kernel" -O > /dev/mmcblk0p8
    tar -xf "$tar_file" "${board_dir}/rootfs" -O > /dev/mmcblk0p9

    if command -v fw_setenv >/dev/null 2>&1; then
        fw_setenv boot_part 2 2>/dev/null || true
    fi
    sync
}
EOF
chmod +x package/base-files/files/lib/upgrade/platform.sh

# 8. Web 端双系统切换面板
cat << 'EOF' > package/base-files/files/usr/lib/lua/luci/controller/dualboot.lua
module("luci.controller.dualboot", package.seeall)

function index()
    entry({"admin", "system", "dualboot"}, call("action_dualboot"), _("双系统切换"), 90).dependent = true
    entry({"admin", "system", "dualboot", "switch"}, call("action_switch")).leaf = true
end

function action_dualboot()
    local cur_boot = luci.util.exec("fw_printenv boot_part 2>/dev/null | awk -F'=' '{print $2}'")
    cur_boot = cur_boot and cur_boot:gsub("%s+", "") or "2"

    local html = [[
        <div class="cbi-map">
            <h2>双系统引导管理 (NRadio C8-688)</h2>
            <div class="cbi-map-descr">当前设备支持 A/B 双槽位无损切换。</div>
            <fieldset class="cbi-section">
                <legend>系统槽位状态</legend>
                <table class="cbi-section-table">
                    <tr class="cbi-section-table-row">
                        <td><b>当前运行槽位：</b></td>
                        <td style="color: green; font-weight: bold;">]] .. (cur_boot == "1" and "主系统 (Slot A / 原厂)" or "副系统 (Slot B / ImmortalWrt)") .. [[</td>
                    </tr>
                    <tr class="cbi-section-table-row">
                        <td><b>操作：</b></td>
                        <td>
                            <button class="cbi-button cbi-button-apply" onclick="location.href=']] .. luci.dispatcher.build_url("admin", "system", "dualboot", "switch") .. [['">
                                ]] .. (cur_boot == "1" and "切换到副系统 (Slot B)" or "一键切回原厂主系统 (Slot A)") .. [[
                            </button>
                        </td>
                    </tr>
                </table>
            </fieldset>
        </div>
    ]]
    luci.template.render_string(html)
end

function action_switch()
    local cur_boot = luci.util.exec("fw_printenv boot_part 2>/dev/null | awk -F'=' '{print $2}'")
    cur_boot = cur_boot and cur_boot:gsub("%s+", "") or "2"
    local target = (cur_boot == "1") and "2" or "1"
    
    luci.util.exec("fw_setenv boot_part " .. target)
    luci.http.redirect(luci.dispatcher.build_url("admin", "system", "dualboot"))
    luci.util.exec("(sleep 2 && reboot) &")
end
EOF

# 9. 创建“蜂窝网络”顶层分类并配置 MT5700M 模组
cat << 'EOF' > package/base-files/files/usr/lib/lua/luci/controller/cellular.lua
module("luci.controller.cellular", package.seeall)

function index()
    entry({"admin", "cellular"}, firstchild(), _("蜂窝网络"), 25).dependent = false
end
EOF

if [ ! -d "package/luci-app-mt5700m" ]; then
    git clone --depth=1 https://github.com/FAN789/luci-app-mt5700m.git package/luci-app-mt5700m 2>/dev/null || true
fi

if [ -d "package/luci-app-mt5700m" ]; then
    find package/luci-app-mt5700m -type f -name "*.lua" | while read -r f; do
        sed -i 's/entry({"admin", "modem"/entry({"admin", "cellular"/g' "$f" 2>/dev/null || true
        sed -i 's/entry({"admin", "network", "mt5700m"/entry({"admin", "cellular", "mt5700m"/g' "$f" 2>/dev/null || true
        sed -i 's/entry({"admin", "network", "mt5700"/entry({"admin", "cellular", "mt5700"/g' "$f" 2>/dev/null || true
    done
    find package/luci-app-mt5700m -type f \( -name "*.lua" -o -name "*.sh" -o -name "*.js" \) | while read -r f; do
        sed -i 's/ttyUSB2/ttyUSB1/g' "$f" 2>/dev/null || true
    done
fi

# 10. 拉取风扇温控插件
if [ ! -d "package/luci-app-h5000m-fancontrol" ]; then
    git clone --depth=1 https://github.com/FAN789/luci-app-h5000m-fancontrol.git package/luci-app-h5000m-fancontrol 2>/dev/null || true
fi

# 11. 自动适配上游内核并注入 NRadio C8-688 设备支持
# -----------------------------------------------------------------------------
echo "Injecting NRadio C8-688 device support dynamically..."

# (1) 自动寻找当前上游 mediatek 平台使用的所有内核 files 目录 (例如 files-6.6, files-6.12 等)
for files_dir in target/linux/mediatek/files-*; do
    if [ -d "$files_dir" ]; then
        # 确保对应内核版本的 DTS 目录存在，并将设备树复制进去
        mkdir -p "$files_dir/arch/arm64/boot/dts/mediatek/"
        cp $GITHUB_WORKSPACE/mt7981b-nradio-c8-688.dts "$files_dir/arch/arm64/boot/dts/mediatek/"
        echo "Successfully injected DTS into $files_dir"
    fi
done

# (2) 向 target/linux/mediatek/image/filogic.mk 追加设备编译定义
cat << 'EOF' >> target/linux/mediatek/image/filogic.mk

define Device/nradio_c8-688
  DEVICE_VENDOR := NRadio
  DEVICE_MODEL := C8-688
  DEVICE_DTS := mt7981b-nradio-c8-688
  DEVICE_DTS_DIR := $$(DTS_DIR)/mediatek
  SUPPORTED_DEVICES := nradio,c8-688
  DEVICE_PACKAGES := kmod-mt7981-firmware mt7981-wo-firmware
  
  # 覆盖上游默认规则，彻底抛弃 .itb，仅生成适配双系统脚本的 sysupgrade.bin (Tarball)
  IMAGES := sysupgrade.bin
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += nradio_c8-688
EOF
