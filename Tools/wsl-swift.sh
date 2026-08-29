#!/bin/bash
# WSL 内运行 Linux 原生 Swift（build/test），供 build.ps1 与手工调用。
# 用法: wsl -d Ubuntu bash Tools/wsl-swift.sh build --target ZhiMingCore ...
# 工具链路径与 build.ps1 保持一致（swift-6.3.3-RELEASE-ubuntu24.04）。
export PATH="/opt/swift-6.3.3-RELEASE-ubuntu24.04/usr/bin:/usr/local/bin:/usr/bin:/bin"
export LD_LIBRARY_PATH="/opt/swift-6.3.3-RELEASE-ubuntu24.04/usr/lib/swift/linux"
cd /mnt/d/iOS/ZhiMing || exit 1
# Linux 原生产物与 xtool 交叉编译产物隔离，避免相互污染
exec swift "${@}" 2>&1
