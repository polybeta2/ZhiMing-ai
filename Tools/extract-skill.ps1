# 从 fictional-erotica 仓库提取单语言版本：
# 仓库为逐段中英对照（EN 段落 + 中文段落交替），本脚本按块内 CJK/拉丁字符占比
# 把每个 md 文件拆成 skill.zh.md 与 skill.en.md 两份纯语言文件。
# 规则：标题行与表格、围栏代码块保留在两个版本；YAML frontmatter 丢弃；
#       “Route References / 参考文件路由”导航节丢弃（由桥接说明替代）。
param(
    [Parameter(Mandatory=$true)][string]$RepoDir,
    [Parameter(Mandatory=$true)][string]$OutDir
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

function Count-Script([string]$text, [ref]$cjkRef, [ref]$latRef) {
    foreach ($ch in $text.ToCharArray()) {
        $v = [int]$ch
        if (($v -ge 0x4E00 -and $v -le 0x9FFF) -or ($v -ge 0x3400 -and $v -le 0x4DBF)) { $cjkRef.Value++ }
        elseif (($v -ge 0x41 -and $v -le 0x5A) -or ($v -ge 0x61 -and $v -le 0x7A)) { $latRef.Value++ }
    }
}

function Split-File([string]$path, [string]$relName) {
    $lines = Get-Content -Path $path -Encoding UTF8

    # 去掉 YAML frontmatter
    if ($lines.Count -gt 1 -and $lines[0] -match '^---\s*$') {
        $end = -1
        for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^---\s*$') { $end = $i; break } }
        if ($end -gt 0) { $lines = @($lines[($end+1)..($lines.Count-1)]) }
    }

    # 切块：空行分块；``` 围栏整体一块；“## Route References / 参考文件路由”节跳过
    $blocks = New-Object System.Collections.Generic.List[string]
    $cur = New-Object System.Collections.Generic.List[string]
    $inFence = $false
    $skipRoute = $false
    foreach ($line in $lines) {
        if ($line -match '^\s*```') {
            $inFence = -not $inFence
            $cur.Add($line)
            continue
        }
        if (-not $inFence -and $line -match '^##\s+') {
            $skipRoute = ($line -match 'Route References') -or ($line -match '参考文件路由')
            if ($cur.Count -gt 0) { $blocks.Add(($cur -join "`n")); $cur.Clear() }
            if (-not $skipRoute) { $blocks.Add($line) }
            continue
        }
        if ($skipRoute) { continue }
        if (-not $inFence -and $line -match '^\s*$') {
            if ($cur.Count -gt 0) { $blocks.Add(($cur -join "`n")); $cur.Clear() }
            continue
        }
        $cur.Add($line)
    }
    if ($cur.Count -gt 0) { $blocks.Add(($cur -join "`n")) }

    $zh = New-Object System.Collections.Generic.List[string]
    $en = New-Object System.Collections.Generic.List[string]
    foreach ($block in $blocks) {
        $isHeading = $block.StartsWith('#')
        $isTable = $false
        foreach ($ln in ($block -split "`n")) { if ($ln -match '^\s*\|') { $isTable = $true; break } }
        $isFence = $block.Contains('```')

        $cjk = 0; $lat = 0
        Count-Script $block ([ref]$cjk) ([ref]$lat)

        if ($isHeading -or $isTable -or $isFence) { $zh.Add($block); $en.Add($block); continue }
        if ($cjk -eq 0 -and $lat -eq 0) { continue }
        if ($cjk -ge $lat) { $zh.Add($block) } else { $en.Add($block) }
    }

    return @{
        zh = ($zh -join "`n`n")
        en = ($en -join "`n`n")
    }
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$refs = Get-ChildItem (Join-Path $RepoDir 'fictional-erotica/references') -Filter *.md | ForEach-Object { 'references/' + $_.Name }
$targets = @('SKILL.md') + $refs

$zhAll = New-Object System.Collections.Generic.List[string]
$enAll = New-Object System.Collections.Generic.List[string]
$zhAll.Add('# 虚构情色写作规范 · 中文版（fictional-erotica 本地打包，来源 rs-skills-lab/fictional-erotica，MIT License）')
$enAll.Add('# Fictional Erotica Writing Standard - English edition (bundled from rs-skills-lab/fictional-erotica, MIT License)')
foreach ($t in $targets) {
    $full = Join-Path $RepoDir ("fictional-erotica/" + $t)
    if (-not (Test-Path $full)) { continue }
    $r = Split-File -path $full -relName ("fictional-erotica/" + $t)
    $tag = "### section: $t"
    $zhAll.Add($tag); $zhAll.Add($r.zh)
    $enAll.Add($tag); $enAll.Add($r.en)
}

$bridgeZh = '> 以上为 fictional-erotica 核心规范（本地打包版）。涉及攻受与行为角色、人设与跨场景连续、玩法道具、同人原作锚定、语言对白校准或高级控制台时，对应进阶模块已随包内置，可按需在后续请求中索取。'
$bridgeEn = '> The above is the fictional-erotica core standard (bundled edition). Advanced modules - sexual roles, persona and cross-scene continuity, play & props, canon grounding, dialogue calibration, console - ship in this pack and can be requested when relevant.'

Set-Content -Path (Join-Path $OutDir 'skill.zh.md') -Value (($zhAll -join "`n`n") + "`n`n" + $bridgeZh) -Encoding UTF8
Set-Content -Path (Join-Path $OutDir 'skill.en.md') -Value (($enAll -join "`n`n") + "`n`n" + $bridgeEn) -Encoding UTF8

foreach ($f in @('skill.zh.md', 'skill.en.md')) {
    $p = Join-Path $OutDir $f
    Write-Host ("{0}  {1:N0} chars" -f $f, (Get-Item $p).Length)
}
