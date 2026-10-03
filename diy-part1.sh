#!/bin/bash
cd openwrt

# 1. MT5700M 5G 模块管理插件
git clone --depth=1 https://github.com/LianXia233/luci-app-mt5700m.git package/custom/luci-app-mt5700m

# 2. iStoreOS 风格套件 (QuickStart 首页向导 + iStore 核心库)
git clone --depth=1 https://github.com/linkease/istore.git package/custom/istore
git clone --depth=1 https://github.com/linkease/istore-ui.git package/custom/istore-ui

# 3. OpenClash 源码 (主分支支持 nftables 及 24+/25.x 环境)
git clone --depth=1 -b master https://github.com/vernesong/OpenClash.git package/custom/luci-app-openclash

# 4. Turbo ACC 网络加速 (Flow Offload / BBR / FullCone NAT)
git clone --depth=1 https://github.com/chenmozhijin/luci-app-turboacc.git package/custom/luci-app-turboacc

# 5. 通用温控风扇控制插件 (支持自定义无级调速与手动 PWM 设定)
git clone --depth=1 https://github.com/JiaY-shi/fancontrol.git package/custom/luci-app-fancontrol
