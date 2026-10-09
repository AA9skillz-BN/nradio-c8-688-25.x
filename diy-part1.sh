#!/bin/bash
# -----------------------------------------------------------------------------
# DIY script 1: Executed before feeds update & install
# -----------------------------------------------------------------------------

[ -d "openwrt" ] && cd openwrt

# 1. 引入 Argon 主题与配置面板
if [ ! -d "package/custom/luci-theme-argon" ]; then
    echo "Cloning luci-theme-argon..."
    git clone --depth=1 -b master https://github.com/jerrykuku/luci-theme-argon.git package/custom/luci-theme-argon 2>/dev/null || true
    git clone --depth=1 -b master https://github.com/jerrykuku/luci-app-argon-config.git package/custom/luci-app-argon-config 2>/dev/null || true
fi

# 2. 清理可能存在的依赖元数据缓存
rm -rf tmp

exit 0