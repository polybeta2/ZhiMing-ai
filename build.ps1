# 一键构建织命（ZhiMing）并打包成 .ipa（走 WSL 里的 xtool）
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$root = $PSScriptRoot
$cmd = "cd /mnt/d/iOS/ZhiMing && exec env PATH=/opt/swift-6.3.3-RELEASE-ubuntu24.04/usr/bin:/usr/local/bin:/usr/bin:/bin LD_LIBRARY_PATH=/opt/swift-6.3.3-RELEASE-ubuntu24.04/usr/lib/swift/linux /opt/xtool dev build --ipa 2>&1 | grep -v 'no version information available'"

wsl -d Ubuntu bash -lc $cmd
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
