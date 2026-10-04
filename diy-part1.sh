#!/bin/bash
# -----------------------------------------------------------------------------
# DIY script 1: Executed before feeds update & install
# -----------------------------------------------------------------------------

# 确保在 openwrt 源码目录或当前工作区执行
[ -d "openwrt" ] && cd openwrt

# 1. 引入 AutoUpdate 在线 OTA 升级插件源码
if [ ! -d "package/custom/luci-app-autoupdate" ]; then
    echo "Cloning luci-app-autoupdate..."
    git clone --depth=1 https://github.com/Hyy2001X/luci-app-autoupdate.git package/custom/luci-app-autoupdate 2>/dev/null || true
fi

# 2. 根治已淘汰的 kmod-usb2 声明，避免 feeds 产生冗余依赖报错
find package/ -type f -name "Makefile" -exec sed -i 's/+kmod-usb2//g' {} + 2>/dev/null || true

# 3. 清理可能存在的依赖元数据缓存
rm -rf tmp

exit 0
