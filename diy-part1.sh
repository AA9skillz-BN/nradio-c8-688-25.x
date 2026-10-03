#!/bin/bash
# --------------------------------------------------------
# DIY script 1: Executed before feeds update & install
# --------------------------------------------------------

cd openwrt || true

# 1. 引入 5G 模组管理插件源 (MT5700M)
if [ ! -d "package/custom/luci-app-mt5700m" ]; then
    git clone --depth=1 https://github.com/kossev-io/luci-app-mt5700m.git package/custom/luci-app-mt5700m 2>/dev/null || true
fi

# 2. 引入在线 OTA 升级插件 (luci-app-autoupdate)
if [ ! -d "package/custom/luci-app-autoupdate" ]; then
    git clone --depth=1 https://github.com/Hyy2001X/luci-app-autoupdate.git package/custom/luci-app-autoupdate 2>/dev/null || true
fi

# 3. 【核心根治】在 feeds 建立索引前，彻底从源码中剔除已淘汰的 kmod-usb2 依赖
find package/ -type f -name "Makefile" -exec sed -i 's/+kmod-usb2//g' {} + 2>/dev/null || true

# 4. 彻底清空临时依赖缓存目录，防止残留过期的依赖元数据
rm -rf tmp
