#!/bin/bash
# -----------------------------------------------------------------------------
# DIY script 2: Executed after feeds update & install, before make defconfig
# 适配 ImmortalWrt 25.x / master 分支
# -----------------------------------------------------------------------------

[ -d "openwrt" ] && cd openwrt

# 1. 注入 NRadio C8-688 设备树 (DTS)
WORKSPACE_ROOT="${GITHUB_WORKSPACE:-$(pwd)/..}"
DTS_SOURCE="${WORKSPACE_ROOT}/mt7981b-nradio-c8-688.dts"

if [ -f "$DTS_SOURCE" ]; then
    echo "Found custom DTS: $DTS_SOURCE"
    for files_dir in target/linux/mediatek/files-*; do
        if [ -d "$files_dir" ]; then
            mkdir -p "$files_dir/arch/arm64/boot/dts/mediatek/"
            cp -f "$DTS_SOURCE" "$files_dir/arch/arm64/boot/dts/mediatek/"
            echo "Injected DTS into $files_dir"
        fi
    done
    mkdir -p target/linux/mediatek/dts/
    cp -f "$DTS_SOURCE" target/linux/mediatek/dts/
fi

# 2. 向 filogic.mk 追加设备编译定义 (仅保留一份，避免冲突重复)
FILOGIC_MK="target/linux/mediatek/image/filogic.mk"
if [ -f "$FILOGIC_MK" ] && ! grep -q "define Device/nradio_c8-688" "$FILOGIC_MK"; then
    echo "Injecting Device/nradio_c8-688 into filogic.mk..."
    cat << 'EOF' >> "$FILOGIC_MK"

define Device/nradio_c8-688
  DEVICE_VENDOR := NRadio
  DEVICE_MODEL := C8-688
  DEVICE_DTS := mt7981b-nradio-c8-688
  DEVICE_DTS_DIR := $(DTS_DIR)/mediatek
  SUPPORTED_DEVICES := nradio,c8-688 nradio,c8-668
  DEVICE_PACKAGES := kmod-mt7981-firmware mt7981-wo-firmware kmod-usb-net-cdc-ether kmod-usb-net-rndis kmod-usb-serial-option
  IMAGES := sysupgrade.bin
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += nradio_c8-688
EOF
fi

# 3. 修改默认后台 LAN IP 为 192.168.66.1
sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate

# 4. 清理旧版废弃的 kmod-usb2 声明
find package/ feeds/ -name "Makefile" -o -name "*.mk" | xargs sed -i 's/+kmod-usb2//g' 2>/dev/null || true

# 5. 准备自定义目录结构
mkdir -p package/base-files/files/etc/uci-defaults
mkdir -p package/base-files/files/lib/upgrade
mkdir -p package/base-files/files/usr/lib/lua/luci/controller

# 6. 配置 U-Boot 环境变量映射文件 (供 dualboot 与 autoupdate 使用)
cat << 'EOF' > package/base-files/files/etc/fw_env.config
# MTD/MMC device name   Device offset   Env size
/dev/mmcblk0            0x100000        0x80000
EOF

# 7. 首次开机自适应扩展 8GB eMMC 分区空间 (/overlay 撑满)
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

# 8. 配置 AutoUpdate 绑定仓库
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

# 9. 升级脚本：锁死写入 Slot B (mmcblk0p8 / mmcblk0p9)
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

# 10. Web 端双系统切换面板
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

# 11. 创建“蜂窝网络”顶层分类并配置 MT5700M 模组
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

# 12. 模组默认串口锁定为 ttyUSB1
cat << 'EOF' > package/base-files/files/etc/uci-defaults/98-mt5700m-default
#!/sh
if [ -f /etc/config/mt5700m ]; then
    uci -q batch << EOU
set mt5700m.@mt5700m[0].port='/dev/ttyUSB1'
commit mt5700m
EOU
fi
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/98-mt5700m-default

# 13. 拉取风扇温控插件
if [ ! -d "package/luci-app-h5000m-fancontrol" ]; then
    git clone --depth=1 https://github.com/FAN789/luci-app-h5000m-fancontrol.git package/luci-app-h5000m-fancontrol 2>/dev/null || true
fi

exit 0