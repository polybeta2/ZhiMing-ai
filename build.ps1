# 一键构建织命（ZhiMing）并打包成 .ipa（走 WSL 里的 xtool）
# 用法: build.ps1          构建 ipa（TrollStore 侧载用）
#       build.ps1 -Test    跑 Linux 原生测试（ZhiMingCore 的 XCTest 基线，无需 Mac）
# 说明: v2.2.1 起用 PIPESTATUS 取真实退出码——原先 `| grep -v` 管道会让
#       $LASTEXITCODE 变成 grep 的退出码，掩盖 xtool 的构建失败。
param([switch]$Test)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$root = $PSScriptRoot

if ($Test) {
    # Linux 原生测试：App 层源文件带平台守卫，在非 Apple 平台编译为空模块，
    # 因此 swift test 可以全量构建（详见 docs/project_memory.md 测试基建一节）
    $cmd = 'bash /mnt/d/iOS/ZhiMing/Tools/wsl-swift.sh test --scratch-path ~/zm-build 2>&1 | grep -v "no version information"; exit ${PIPESTATUS[0]}'
    wsl -d Ubuntu bash -c $cmd
    if ($LASTEXITCODE -ne 0) {
        Write-Error "测试失败，退出码 $LASTEXITCODE"
    }
    Write-Host "OK: swift test 全部通过"
    exit 0
}

$cmd = 'cd /mnt/d/iOS/ZhiMing && exec env PATH=/opt/swift-6.3.3-RELEASE-ubuntu24.04/usr/bin:/usr/local/bin:/usr/bin:/bin LD_LIBRARY_PATH=/opt/swift-6.3.3-RELEASE-ubuntu24.04/usr/lib/swift/linux /opt/xtool dev build --ipa 2>&1 | grep -v "no version information available"; exit ${PIPESTATUS[0]}'

wsl -d Ubuntu bash -c $cmd
if ($LASTEXITCODE -ne 0) {
    Write-Error "构建失败，退出码 $LASTEXITCODE"
}

$ipa = Get-ChildItem (Join-Path $root 'xtool\*.ipa') -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($ipa) {
    Write-Host ("OK -> " + $ipa.FullName + "  (" + [math]::Round($ipa.Length / 1KB) + " KB)")
    # 复制一份到工程根，方便 TrollStore 侧载
    $copy = Join-Path $root 'ZhiMing.ipa'
    Copy-Item $ipa.FullName $copy -Force
    Write-Host ("副本 -> " + $copy)
} else {
    Write-Warning "未找到 .ipa，请检查 xtool 版本是否支持 --ipa"
}
