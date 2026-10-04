#!/bin/bash
# --------------------------------------------------------
# DIY script 1: Executed before feeds update & install
# --------------------------------------------------------

# 确保在 openwrt 源码根目录操作
[ -d "openwrt" ] && cd openwrt

# 1. 引入在线 OTA 升级插件 (luci-app-autoupdate)
if [ ! -d "package/custom/luci-app-autoupdate" ]; then
    git clone --depth=1 https://github.com/Hyy2001X/luci-app-autoupdate.git package/custom/luci-app-autoupdate 2>/dev/null || true
fi

# 2. 【核心根治】在 feeds 建立索引前，彻底从源码中剔除已淘汰的 kmod-usb2 依赖
find package/ -type f -name "Makefile" -exec sed -i 's/+kmod-usb2//g' {} + 2>/dev/null || true

# 3. 彻底清空临时依赖缓存目录，防止残留过期的依赖元数据
rm -rf tmp
