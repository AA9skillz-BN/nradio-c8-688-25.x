#!/bin/bash
# -----------------------------------------------------------------------------
# DIY script 2: NRadio C8-688 纯净稳定版构建脚本
# 适配 ImmortalWrt 25.x / Linux 6.12 / fw4 (nftables) / DualBoot Slot B
# -----------------------------------------------------------------------------

[ -d "openwrt" ] && cd openwrt

# 1. 注入设备树 (DTS)
DTS_SOURCE=""
for search_path in \
    "${GITHUB_WORKSPACE}/mt7981b-nradio-c8-688.dts" \
    "$(pwd)/../mt7981b-nradio-c8-688.dts" \
    "$(pwd)/mt7981b-nradio-c8-688.dts"; do
    if [ -f "$search_path" ]; then
        DTS_SOURCE="$search_path"
        break
    fi
done

if [ -n "$DTS_SOURCE" ]; then
    echo "Found custom DTS: $DTS_SOURCE"
    mkdir -p target/linux/mediatek/dts/
    cp -f "$DTS_SOURCE" target/linux/mediatek/dts/

    for files_dir in target/linux/mediatek/files target/linux/mediatek/files-*; do
        if [ -d "$files_dir" ]; then
            mkdir -p "$files_dir/arch/arm64/boot/dts/mediatek/"
            cp -f "$DTS_SOURCE" "$files_dir/arch/arm64/boot/dts/mediatek/"
        fi
    done
else
    echo "ERROR: mt7981b-nradio-c8-688.dts not found!"
    exit 1
fi

# 2. 向 filogic.mk 追加设备定义 (彻底剔除多余的 DEVICE_DTS_DIR，杜绝路径重复嵌套报错)
FILOGIC_MK="target/linux/mediatek/image/filogic.mk"
if [ -f "$FILOGIC_MK" ] && ! grep -q "define Device/nradio_c8-688" "$FILOGIC_MK"; then
    echo "Injecting Device/nradio_c8-688 into filogic.mk..."
    cat << 'EOF' >> "$FILOGIC_MK"

define Device/nradio_c8-688
  DEVICE_VENDOR := NRadio
  DEVICE_MODEL := C8-688
  DEVICE_DTS := mt7981b-nradio-c8-688
  SOC := mt7981
  SUPPORTED_DEVICES := nradio,c8-688 nradio,c8-668
  DEVICE_PACKAGES := kmod-mt7981-firmware mt7981-wo-firmware kmod-usb-net-cdc-ether kmod-usb-net-rndis kmod-usb-net-cdc-mbim kmod-usb-serial-option
  IMAGES := sysupgrade.bin
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += nradio_c8-688
EOF
fi

# 3. 基础设置：LAN IP 默认设为 192.168.66.1
sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate

# 4. 清理旧版废弃的 kmod-usb2 声明
find package/ feeds/ -name "Makefile" -o -name "*.mk" | xargs sed -i 's/+kmod-usb2//g' 2>/dev/null || true

# 5. 准备目录结构
mkdir -p package/base-files/files/etc/uci-defaults
mkdir -p package/base-files/files/etc/hotplug.d/net
mkdir -p package/base-files/files/etc/nftables.d
mkdir -p package/base-files/files/etc/rc.button
mkdir -p package/base-files/files/etc/crontabs
mkdir -p package/base-files/files/lib/upgrade
mkdir -p package/base-files/files/usr/bin
mkdir -p package/base-files/files/usr/lib/lua/luci/controller

# 6. 配置 U-Boot 环境变量映射文件 (增加多重容错探测逻辑)
cat << 'EOF' > package/base-files/files/etc/uci-defaults/01-fw-env-detect
#!/bin/sh
if [ -b "/dev/mmcblk0p2" ] && grep -qi "ubootenv" /proc/partitions 2>/dev/null; then
    echo "/dev/mmcblk0p2 0x0 0x80000" > /etc/fw_env.config
elif [ ! -f /etc/fw_env.config ]; then
    cat << 'CONF' > /etc/fw_env.config
/dev/mmcblk0 0x100000 0x80000 0x80000
/dev/mmcblk0 0x180000 0x80000 0x80000
CONF
fi
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/01-fw-env-detect

# 7. 实装 TCP BBR 拥塞控制与 FQ 队列调度
cat << 'EOF' >> package/base-files/files/etc/sysctl.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

# 8. 防火墙出站 TTL 锁定 64 与 TCP MSS 钳制
cat << 'EOF' > package/base-files/files/etc/nftables.d/10-custom-ttl.nft
table inet fw4 {
    chain forward_mss_clamp {
        type filter hook forward priority 0; policy accept;
        tcp flags syn tcp option maxseg size set rt mtu
    }
    chain postrouting_mangle_ttl {
        type filter hook postrouting priority 300; policy accept;
        ip ttl set 64
        ip6 hoplimit set 64
    }
}
EOF

# 9. 流量统计 nlbwmon 默认参数初始化
cat << 'EOF' > package/base-files/files/etc/uci-defaults/94-nlbwmon-setup
#!/bin/sh
uci set nlbwmon.@nlbwmon[0].commit_interval='24h'
uci set nlbwmon.@nlbwmon[0].refresh_interval='30s'
uci -q del_list nlbwmon.@nlbwmon[0].local_network='192.168.66.0/24'
uci add_list nlbwmon.@nlbwmon[0].local_network='192.168.66.0/24'
uci commit nlbwmon
/etc/init.d/nlbwmon enable 2>/dev/null || true
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/94-nlbwmon-setup

# 10. 蜂窝 5G IPv6 Relay (中继 / 穿透) 自动化配置
cat << 'EOF' > package/base-files/files/etc/uci-defaults/95-ipv6-relay
#!/bin/sh
uci set network.lan.delegate='0'
uci commit network

uci set dhcp.lan.ra='relay'
uci set dhcp.lan.dhcpv6='relay'
uci set dhcp.lan.ndp='relay'

uci -q delete dhcp.modem_5g_6
uci set dhcp.modem_5g_6=dhcp
uci set dhcp.modem_5g_6.interface='modem_5g_6'
uci set dhcp.modem_5g_6.ra='relay'
uci set dhcp.modem_5g_6.dhcpv6='relay'
uci set dhcp.modem_5g_6.ndp='relay'
uci set dhcp.modem_5g_6.master='1'
uci commit dhcp
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/95-ipv6-relay

# 11. 出厂默认开启 Wi-Fi 并设置 160MHz 满血频宽 + 密码防护
cat << 'EOF' > package/base-files/files/etc/uci-defaults/97-default-wifi
#!/bin/sh
wifi config 2>/dev/null || true

radio_idx=0
for dev in $(uci -q show wireless | grep "=wifi-device" | cut -d'.' -f2 | cut -d'=' -f1); do
    uci set wireless.${dev}.disabled='0'
    if [ "$radio_idx" -eq 0 ]; then
        uci set wireless.${dev}.country='CN'
        uci -q set wireless.default_${dev}.ssid='NRadio-C8-688-2.4G'
        uci -q set wireless.default_${dev}.encryption='psk2'
        uci -q set wireless.default_${dev}.key='12345678'
    else
        uci set wireless.${dev}.country='CN'
        uci set wireless.${dev}.channel='36'
        uci set wireless.${dev}.htmode='HE160'
        uci -q set wireless.default_${dev}.ssid='NRadio-C8-688-5G'
        uci -q set wireless.default_${dev}.encryption='psk2'
        uci -q set wireless.default_${dev}.key='12345678'
    fi
    radio_idx=$((radio_idx + 1))
done

uci commit wireless
wifi reload 2>/dev/null || true
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/97-default-wifi

# 12. 5G 基站 NITZ 自动授时 (集成原子排他锁与进程捕获)
cat << 'EOF' > package/base-files/files/usr/bin/modem_nitz_sync
#!/bin/sh
PORT="/dev/ttyUSB1"
[ -c "$PORT" ] || exit 0
command -v sms_tool >/dev/null 2>&1 || exit 0

LOCKDIR="/var/lock/modem_at.lock"
trap 'rm -rf "$LOCKDIR"' EXIT INT TERM

acquired=0
for i in $(seq 1 10); do
    if mkdir "$LOCKDIR" 2>/dev/null; then
        acquired=1
        break
    fi
    sleep 0.5
done

[ "$acquired" -eq 1 ] || exit 1

RESP=$(sms_tool -d "$PORT" at "AT+CCLK?" 2>/dev/null | grep -i "+CCLK:" | head -n 1)

if [ -n "$RESP" ]; then
    RAW_TIME=$(echo "$RESP" | sed -n 's/.*"\([0-9\/]*,[0-9:]*\).*/\1/p')
    if [ -n "$RAW_TIME" ]; then
        FORMATTED_TIME=$(echo "$RAW_TIME" | awk -F'[/,:]' '{printf "%02d%02d%02d%02d20%02d.%02d", $2, $3, $4, $5, $1, $6}')
        date "$FORMATTED_TIME" >/dev/null 2>&1 || date -s "$FORMATTED_TIME" >/dev/null 2>&1
        logger -t "NITZ" "已成功同步 5G 基站网络时间: $FORMATTED_TIME"
    fi
fi
rm -rf "$LOCKDIR"
EOF
chmod +x package/base-files/files/usr/bin/modem_nitz_sync

# 13. 注入 5G 模组自适应热插拔与双栈网络支持
cat << 'EOF' > package/base-files/files/etc/hotplug.d/net/99-modem-auto
#!/bin/sh
case "$INTERFACE" in
    usb*|wwan*)
        if [ "$ACTION" = "add" ]; then
            CURRENT_DEV=$(uci -q get network.modem_5g.device)
            if [ -n "$CURRENT_DEV" ] && [ -d "/sys/class/net/$CURRENT_DEV" ] && [ "$CURRENT_DEV" != "$INTERFACE" ]; then
                exit 0
            fi

            if uci -q get firewall.@zone[1] >/dev/null; then
                uci -q del_list firewall.@zone[1].network='modem_5g'
                uci add_list firewall.@zone[1].network='modem_5g'
                uci -q del_list firewall.@zone[1].network='modem_5g_6'
                uci add_list firewall.@zone[1].network='modem_5g_6'
                uci commit firewall
                /etc/init.d/firewall reload >/dev/null 2>&1
            fi

            uci set network.modem_5g=interface
            uci set network.modem_5g.proto='dhcp'
            uci set network.modem_5g.device="$INTERFACE"
            uci set network.modem_5g.metric='10'

            uci set network.modem_5g_6=interface
            uci set network.modem_5g_6.proto='dhcpv6'
            uci set network.modem_5g_6.device="$INTERFACE"
            uci set network.modem_5g_6.reqaddress='try'
            uci set network.modem_5g_6.reqprefix='auto'
            uci set network.modem_5g_6.metric='10'
            uci commit network

            /etc/init.d/network reload >/dev/null 2>&1
            /etc/init.d/odhcpd reload >/dev/null 2>&1
            ( sleep 2; ifup modem_5g; ifup modem_5g_6; sleep 3; /usr/bin/modem_nitz_sync ) &
        fi
        ;;
esac
EOF
chmod +x package/base-files/files/etc/hotplug.d/net/99-modem-auto

# 14. 5G 模组掉线自愈看门狗脚本
cat << 'EOF' > package/base-files/files/usr/bin/modem_watchdog
#!/bin/sh
DNS_TARGETS="223.5.5.5 119.29.29.29 8.8.8.8"
FAIL_LOG="/tmp/modem_watchdog_fails"
[ -f "$FAIL_LOG" ] || echo "0" > "$FAIL_LOG"

is_online=0
for ip in $DNS_TARGETS; do
    if ping -c 1 -W 3 -q -I modem_5g "$ip" >/dev/null 2>&1; then
        is_online=1
        break
    fi
done

if [ "$is_online" -eq 1 ]; then
    echo "0" > "$FAIL_LOG"
    exit 0
fi

FAILS=$(cat "$FAIL_LOG")
FAILS=$((FAILS + 1))
echo "$FAILS" > "$FAIL_LOG"
logger -t "ModemWatchdog" "5G 蜂窝网络不可达，当前连续失败次数: $FAILS"

if [ "$FAILS" -eq 2 ]; then
    logger -t "ModemWatchdog" "连续 2 次探测超时，正在重启网络接口..."
    ifup modem_5g
    ifup modem_5g_6
elif [ "$FAILS" -ge 4 ]; then
    logger -t "ModemWatchdog" "连续 4 次探测超时，触发模组硬件 AT 软复位 (CFUN)..."
    if [ -c /dev/ttyUSB1 ]; then
        LOCKDIR="/var/lock/modem_at.lock"
        trap 'rm -rf "$LOCKDIR"' EXIT INT TERM
        for i in $(seq 1 10); do
            if mkdir "$LOCKDIR" 2>/dev/null; then
                echo -e "AT+CFUN=0\r\n" > /dev/ttyUSB1
                sleep 3
                echo -e "AT+CFUN=1\r\n" > /dev/ttyUSB1
                rm -rf "$LOCKDIR"
                break
            fi
            sleep 0.5
        done
    fi
    /etc/init.d/network restart
    /etc/init.d/odhcpd restart >/dev/null 2>&1
    echo "0" > "$FAIL_LOG"
fi
EOF
chmod +x package/base-files/files/usr/bin/modem_watchdog

cat << 'EOF' > package/base-files/files/etc/crontabs/root
*/2 * * * * /usr/bin/modem_watchdog >/dev/null 2>&1
EOF

# 15. 实体 Reset 按键盲切救砖机制
cat << 'EOF' > package/base-files/files/etc/rc.button/reset
#!/bin/sh
[ "${ACTION}" = "released" ] || exit 0
. /lib/functions.sh

logger -t "ResetButton" "Reset 实体键被释放，按压持续时间: ${SEEN} 秒"

if [ "$SEEN" -ge 10 ]; then
    echo "=== [灾难救回] 触发实体按键长按，强制切回原厂主系统 (Slot A) ===" > /dev/console
    fw_setenv boot_part 1
    sync
    reboot
elif [ "$SEEN" -ge 4 ]; then
    echo "=== 触发恢复出厂设置 ===" > /dev/console
    firstboot -y && reboot
fi
exit 0
EOF
chmod +x package/base-files/files/etc/rc.button/reset

# 16. 平台升级脚本：适配 sysupgrade-tar 并锁死 Slot B
PLATFORM_SCRIPT='#!/bin/sh
RAMFS_COPY_BIN="${RAMFS_COPY_BIN} /usr/sbin/fw_printenv /usr/sbin/fw_setenv /bin/tar"

platform_check_image() {
    local tar_file="$1"
    [ -f "$tar_file" ] || return 1
    tar -tf "$tar_file" >/dev/null 2>&1 || return 1

    local board_dir=$(tar -tf "$tar_file" | grep -m 1 "^sysupgrade-.*/$")
    board_dir="${board_dir%/}"
    [ -n "$board_dir" ] || return 1

    tar -tf "$tar_file" | grep -q "${board_dir}/kernel" || return 1
    tar -tf "$tar_file" | grep -Eq "${board_dir}/(root|rootfs)" || return 1
    return 0
}

platform_do_upgrade() {
    local tar_file="$1"
    local board_dir=$(tar -tf "$tar_file" | grep -m 1 "^sysupgrade-.*/$")
    board_dir="${board_dir%/}"

    echo "=== [DualBoot] 正在刷入副系统 Slot B (Kernel: mmcblk0p8, Rootfs: mmcblk0p9) ==="
    tar -xf "$tar_file" "${board_dir}/kernel" -O > /dev/mmcblk0p8

    if tar -tf "$tar_file" | grep -q "${board_dir}/rootfs"; then
        tar -xf "$tar_file" "${board_dir}/rootfs" -O > /dev/mmcblk0p9
    elif tar -tf "$tar_file" | grep -q "${board_dir}/root"; then
        tar -xf "$tar_file" "${board_dir}/root" -O > /dev/mmcblk0p9
    fi

    if command -v fw_setenv >/dev/null 2>&1; then
        echo "Locking boot_part to 2 (Slot B)..."
        fw_setenv boot_part 2 2>/dev/null || true
    fi

    sync
    echo "=== Slot B Upgrade Completed Successfully ==="
}
'

echo "$PLATFORM_SCRIPT" > package/base-files/files/lib/upgrade/platform.sh
chmod +x package/base-files/files/lib/upgrade/platform.sh

TARGET_UPGRADE_DIR="target/linux/mediatek/filogic/base-files/lib/upgrade"
mkdir -p "$TARGET_UPGRADE_DIR"
echo "$PLATFORM_SCRIPT" > "$TARGET_UPGRADE_DIR/platform.sh"
chmod +x "$TARGET_UPGRADE_DIR/platform.sh"

# 17. 底层 OTA 执行脚本
cat << 'EOF' > package/base-files/files/usr/bin/c8_autoupdate
#!/bin/sh
REPO="AA9skillz-BN/nradio-c8-688-25.x"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"
TMP_IMG="/tmp/sysupgrade.bin"

echo "=== [OTA] 正在检测 GitHub Release 最新版本 [${REPO}] ==="
RELEASE_JSON=$(curl -sL --connect-timeout 10 "$API_URL")
if [ -z "$RELEASE_JSON" ]; then
    echo "[错误] 无法连接到 GitHub API，请检查网络。"
    exit 1
fi

TAG_NAME=$(echo "$RELEASE_JSON" | jq -r '.tag_name // empty')
echo "线上最新版本标签: ${TAG_NAME:-未知}"

DOWNLOAD_URL=$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name | test(".*nradio_c8-688.*sysupgrade\\.bin$")) | .browser_download_url' | head -n 1)

if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
    echo "[错误] 未检测到匹配的固件包！"
    exit 1
fi

echo "固件下载地址: $DOWNLOAD_URL"
if [ "$1" = "check" ]; then
    echo "=== 检测完毕：有可用新固件 (${TAG_NAME}) ==="
    exit 0
fi

echo "正在下载固件到本地内存..."
rm -f "$TMP_IMG"
curl -L -k --connect-timeout 15 -o "$TMP_IMG" "$DOWNLOAD_URL"

if [ ! -s "$TMP_IMG" ]; then
    echo "[错误] 固件下载失败。"
    exit 1
fi

echo "固件完整性校验中..."
if ! sysupgrade -t "$TMP_IMG"; then
    echo "[错误] 固件校验不通过，已中止！"
    rm -f "$TMP_IMG"
    exit 1
fi

echo "校验通过，正在烧录至 Slot B 并重启..."
sleep 2
sysupgrade -n "$TMP_IMG"
EOF
chmod +x package/base-files/files/usr/bin/c8_autoupdate

# 18. LuCI OTA 在线更新控制器 (全屏极客动效 + 实时流式终端 + 75秒探活重连)
cat << 'EOF' > package/base-files/files/usr/lib/lua/luci/controller/c8_autoupdate.lua
module("luci.controller.c8_autoupdate", package.seeall)

function index()
    entry({"admin", "system", "c8_autoupdate"}, call("action_index"), _("在线更新"), 89).dependent = true
    entry({"admin", "system", "c8_autoupdate", "run"}, call("action_run")).leaf = true
end

function action_index()
    local html = [[
        <style>
            #ota-reboot-overlay {
                display: none;
                position: fixed;
                top: 0; left: 0; width: 100vw; height: 100vh;
                background: rgba(15, 23, 42, 0.94);
                backdrop-filter: blur(10px);
                z-index: 99999;
                flex-direction: column;
                justify-content: center;
                align-items: center;
                color: #fff;
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            }
            .ota-spinner {
                width: 68px;
                height: 68px;
                border: 4px solid rgba(255, 255, 255, 0.12);
                border-top: 4px solid #10b981;
                border-radius: 50%;
                animation: ota-spin 1s cubic-bezier(0.55, 0.15, 0.45, 0.85) infinite;
                margin-bottom: 24px;
            }
            @keyframes ota-spin {
                0% { transform: rotate(0deg); }
                100% { transform: rotate(360deg); }
            }
            .ota-title { font-size: 22px; font-weight: 600; margin-bottom: 10px; color: #f8fafc; }
            .ota-desc { font-size: 14px; color: #94a3b8; margin-bottom: 20px; }
            .ota-timer { font-size: 16px; font-weight: 500; color: #34d399; }
        </style>

        <div id="ota-reboot-overlay">
            <div class="ota-spinner"></div>
            <div class="ota-title">固件烧录完毕，正在重启设备...</div>
            <div class="ota-desc">Slot B 新系统正在初始化，硬件重新加载中，请勿切断电源</div>
            <div class="ota-timer">预计就绪倒计时：<span id="ota-countdown">75</span> 秒</div>
        </div>

        <div class="cbi-map" id="cbi-autoupdate">
            <h2 name="content">在线更新 (NRadio C8-688)</h2>
            <div class="cbi-map-descr">当前运行在 DualBoot 架构，一键升级将安全锁定并仅覆盖副系统 (Slot B)，出厂原厂系统物理绝缘免受冲击。</div>
            <fieldset class="cbi-section">
                <legend>固件升级控制台</legend>
                <div style="display: flex; gap: 12px; margin-bottom: 16px;">
                    <button id="btn-check" class="cbi-button cbi-button-apply" style="padding: 6px 18px;" onclick="executeOTA('check')">🔍 仅检查新版本</button>
                    <button id="btn-upgrade" class="cbi-button cbi-button-reset" style="background-color: #0072ff; color: #fff; padding: 6px 18px;" onclick="startUpgrade()">🚀 一键在线升级并重启</button>
                </div>
                <div id="ota-terminal-box" style="margin-top: 15px;">
                    <label><b>实时升级日志终端：</b></label>
                    <pre id="ota-output" style="background: #111827; color: #10b981; padding: 15px; border-radius: 8px; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-size: 13px; line-height: 1.5; height: 340px; overflow-y: auto; white-space: pre-wrap; word-break: break-all; border: 1px solid #374151;">点击上方按钮开始检测...</pre>
                </div>
            </fieldset>
            <script type="text/javascript">
                function startUpgrade() {
                    if (!confirm('确认立即从 GitHub Release 下载最新固件并烧录至 Slot B 吗？\n升级写入完成后设备将自动重启。')) {
                        return;
                    }
                    executeOTA('upgrade');
                }

                function triggerRebootOverlay() {
                    var overlay = document.getElementById('ota-reboot-overlay');
                    overlay.style.display = 'flex';
                    var seconds = 75;
                    var timerEl = document.getElementById('ota-countdown');
                    var timer = setInterval(function() {
                        seconds--;
                        if (seconds <= 0) {
                            clearInterval(timer);
                            timerEl.innerText = '正在尝试重新接入系统...';
                            checkAndRedirect();
                        } else {
                            timerEl.innerText = seconds;
                        }
                    }, 1000);
                }

                function checkAndRedirect() {
                    var interval = setInterval(function() {
                        var ping = new Image();
                        ping.onload = function() {
                            clearInterval(interval);
                            location.href = 'http://' + window.location.hostname;
                        };
                        ping.src = 'http://' + window.location.hostname + '/luci-static/resources/cbi.css?t=' + new Date().getTime();
                    }, 3000);
                }

                function executeOTA(mode) {
                    var out = document.getElementById('ota-output');
                    var btnCheck = document.getElementById('btn-check');
                    var btnUp = document.getElementById('btn-upgrade');
                    
                    btnCheck.disabled = true;
                    btnUp.disabled = true;
                    out.innerText = (mode === 'check' ? '[任务] 正在查询 GitHub Release 最新固件信息...\n' : '[任务] 启动全自动下载、校验与烧录流程...\n');
                    
                    var xhr = new XMLHttpRequest();
                    xhr.open('GET', ']] .. luci.dispatcher.build_url("admin", "system", "c8_autoupdate", "run") .. [[?mode=' + mode, true);
                    var lastIndex = 0;
                    
                    xhr.onprogress = function() {
                        var curr = xhr.responseText.substring(lastIndex);
                        lastIndex = xhr.responseText.length;
                        out.innerText += curr;
                        out.scrollTop = out.scrollHeight;

                        if (curr.indexOf('正在烧录') !== -1 || curr.indexOf('Rebooting') !== -1 || curr.indexOf('sysupgrade') !== -1) {
                            setTimeout(triggerRebootOverlay, 2500);
                        }
                    };
                    
                    xhr.onload = function() {
                        out.scrollTop = out.scrollHeight;
                        btnCheck.disabled = false;
                        btnUp.disabled = false;
                        if (mode === 'upgrade' && out.innerText.indexOf('校验通过') !== -1) {
                            triggerRebootOverlay();
                        }
                    };
                    
                    xhr.onerror = function() {
                        if (mode === 'upgrade') {
                            triggerRebootOverlay();
                        } else {
                            out.innerText += '\n[网络错误] 请求超时或与设备通信中断。';
                            btnCheck.disabled = false;
                            btnUp.disabled = false;
                        }
                    };
                    xhr.send();
                }
            </script>
        </div>
    ]]
    luci.template.render_string(html)
end

function action_run()
    local mode = luci.http.formvalue("mode") or "check"
    luci.http.prepare_content("text/plain; charset=utf-8")
    local cmd = (mode == "upgrade") and "/usr/bin/c8_autoupdate" or "/usr/bin/c8_autoupdate check"
    local handle = io.popen(cmd .. " 2>&1")
    if handle then
        while true do
            local line = handle:read("*l")
            if not line then break end
            luci.http.write(line .. "\n")
        end
        handle:close()
    end
end
EOF

# 19. Web 端双系统一键切换面板 (全屏遮罩 + 75秒平滑重启倒计时)
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
        <style>
            #boot-overlay {
                display: none;
                position: fixed;
                top: 0; left: 0; width: 100vw; height: 100vh;
                background: rgba(15, 23, 42, 0.92);
                backdrop-filter: blur(8px);
                z-index: 99999;
                flex-direction: column;
                justify-content: center;
                align-items: center;
                color: #fff;
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            }
            .boot-spinner {
                width: 64px;
                height: 64px;
                border: 4px solid rgba(255, 255, 255, 0.15);
                border-top: 4px solid #0072ff;
                border-radius: 50%;
                animation: spin 1s cubic-bezier(0.55, 0.15, 0.45, 0.85) infinite;
                margin-bottom: 24px;
            }
            @keyframes spin {
                0% { transform: rotate(0deg); }
                100% { transform: rotate(360deg); }
            }
            .boot-title { font-size: 22px; font-weight: 600; margin-bottom: 8px; letter-spacing: 0.5px; }
            .boot-desc { font-size: 14px; color: #94a3b8; margin-bottom: 20px; }
            .boot-timer { font-size: 16px; font-weight: 500; color: #38bdf8; }
        </style>

        <div id="boot-overlay">
            <div class="boot-spinner"></div>
            <div class="boot-title">正在切换引导槽位并重启路由器...</div>
            <div class="boot-desc">硬件正在写入 U-Boot 引导寄存器，请勿切断路由器电源</div>
            <div class="boot-timer">预计剩余等待时间：<span id="countdown">75</span> 秒</div>
        </div>

        <div class="cbi-map">
            <h2>双系统引导管理 (NRadio C8-688)</h2>
            <div class="cbi-map-descr">当前设备支持 A/B 双槽位物理无损切换。</div>
            <fieldset class="cbi-section">
                <legend>系统槽位状态</legend>
                <table class="cbi-section-table">
                    <tr class="cbi-section-table-row">
                        <td><b>当前运行槽位：</b></td>
                        <td style="color: #10b981; font-weight: bold; font-size: 15px;">]] .. (cur_boot == "1" and "主系统 (Slot A / 原厂出厂系统)" or "副系统 (Slot B / ImmortalWrt)") .. [[</td>
                    </tr>
                    <tr class="cbi-section-table-row">
                        <td><b>操作：</b></td>
                        <td>
                            <button class="cbi-button cbi-button-apply" style="padding: 6px 18px;" onclick="triggerSwitch()">
                                ]] .. (cur_boot == "1" and "🚀 切换到副系统 (Slot B)" or "🔄 一键切回原厂主系统 (Slot A)") .. [[
                            </button>
                        </td>
                    </tr>
                </table>
            </fieldset>
        </div>

        <script type="text/javascript">
            function triggerSwitch() {
                var targetSlot = "]] .. (cur_boot == "1" and "副系统 (Slot B)" or "原厂主系统 (Slot A)") .. [[";
                if (!confirm("确认立即切换至 " + targetSlot + " 并自动重启吗？\n切换过程请保持设备供电正常。")) {
                    return;
                }

                var overlay = document.getElementById('boot-overlay');
                overlay.style.display = 'flex';

                var seconds = 75;
                var timerEl = document.getElementById('countdown');
                var timer = setInterval(function() {
                    seconds--;
                    if (seconds <= 0) {
                        clearInterval(timer);
                        location.href = 'http://' + window.location.hostname;
                    } else {
                        timerEl.innerText = seconds;
                    }
                }, 1000);

                var xhr = new XMLHttpRequest();
                xhr.open('GET', ']] .. luci.dispatcher.build_url("admin", "system", "dualboot", "switch") .. [[', true);
                xhr.send();
            }
        </script>
    ]]
    luci.template.render_string(html)
end

function action_switch()
    local cur_boot = luci.util.exec("fw_printenv boot_part 2>/dev/null | awk -F'=' '{print $2}'")
    cur_boot = cur_boot and cur_boot:gsub("%s+", "") or "2"
    local target = (cur_boot == "1") and "2" or "1"
    luci.util.exec("fw_setenv boot_part " .. target)
    luci.http.prepare_content("text/plain")
    luci.http.write("OK")
    luci.util.exec("(sleep 2 && sync && reboot) &")
end
EOF

# 20. 拉取 MT5700M 模组控制面板
if [ ! -d "package/luci-app-mt5700m" ]; then
    git clone --depth=1 https://github.com/FAN789/luci-app-mt5700m.git package/luci-app-mt5700m 2>/dev/null || true
fi

# 21. 模组默认串口锁定为 ttyUSB1
cat << 'EOF' > package/base-files/files/etc/uci-defaults/98-mt5700m-default
#!/bin/sh
if [ -f /etc/config/mt5700m ]; then
    uci -q batch << EOU
set mt5700m.@mt5700m[0].port='/dev/ttyUSB1'
commit mt5700m
EOU
fi
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/98-mt5700m-default

# 22. 拉取风扇温控插件
if [ ! -d "package/luci-app-h5000m-fancontrol" ]; then
    git clone --depth=1 https://github.com/FAN789/luci-app-h5000m-fancontrol.git package/luci-app-h5000m-fancontrol 2>/dev/null || true
fi

# 23. 拉取短信收发与基站看板
if [ ! -d "package/luci-app-sms-tool-js" ]; then
    git clone --depth=1 https://github.com/4IceG/luci-app-sms-tool-js.git package/luci-app-sms-tool-js 2>/dev/null || true
fi
if [ ! -d "package/sms-tool" ] && [ ! -d "package/feeds/packages/sms-tool" ]; then
    git clone --depth=1 https://github.com/4IceG/openwrt-sms-tool.git package/sms-tool 2>/dev/null || true
fi
if [ ! -d "package/luci-app-3ginfo-lite" ]; then
    git clone --depth=1 https://github.com/4IceG/luci-app-3ginfo-lite.git package/luci-app-3ginfo-lite 2>/dev/null || true
fi

# 24. 规范短信收发与 3Ginfo 基站看板的默认通信串口为 ttyUSB1
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-cellular-addons-default
#!/bin/sh
if [ -f /etc/config/sms_tool ]; then
    uci -q batch << EOU
set sms_tool.@sms_tool[0].port='/dev/ttyUSB1'
commit sms_tool
EOU
fi

if [ -f /etc/config/3ginfo ]; then
    uci -q batch << EOU
set 3ginfo.@3ginfo[0].device='/dev/ttyUSB1'
commit 3ginfo
EOU
fi
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-cellular-addons-default

exit 0