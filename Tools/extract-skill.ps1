# 从 fictional-erotica 仓库提取单语言版本（按模块拆分）：
# 仓库为逐段中英对照，本脚本按块内 CJK/拉丁字符占比，把 SKILL.md 与每个 reference
# 各自拆成纯中文 / 纯英文两份，输出结构：
#   <OutDir>/zh/{core,craft-controls,...}.md
#   <OutDir>/en/{core,craft-controls,...}.md
# 规则：标题行与表格、围栏代码块保留在两个版本；YAML frontmatter 丢弃；
#       “Route References / 参考文件路由”导航节丢弃（运行时由注入器负责路由）。
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

function Split-File([string]$path) {
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

    return @{ zh = ($zh -join "`n`n"); en = ($en -join "`n`n") }
}

$skillRoot = Join-Path $RepoDir 'fictional-erotica'
$targets = @(
    @{ src = 'SKILL.md';                                     name = 'core' },
    @{ src = 'references/craft-controls.md';                 name = 'craft-controls' },
    @{ src = 'references/persona-and-continuity.md';         name = 'persona-and-continuity' },
    @{ src = 'references/sexual-roles.md';                   name = 'sexual-roles' },
    @{ src = 'references/language-and-dialogue.md';          name = 'language-and-dialogue' },
    @{ src = 'references/play-and-props.md';                 name = 'play-and-props' },
    @{ src = 'references/speculative-anatomy.md';            name = 'speculative-anatomy' },
    @{ src = 'references/canon-grounding-and-fanfiction.md'; name = 'canon-grounding-and-fanfiction' },
    @{ src = 'references/core-calibration.md';               name = 'core-calibration' }
)

New-Item -ItemType Directory -Force -Path (Join-Path $OutDir 'zh') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $OutDir 'en') | Out-Null

foreach ($t in $targets) {
    $full = Join-Path $skillRoot $t.src
    if (-not (Test-Path $full)) { Write-Warning "missing: $full"; continue }
    $r = Split-File -path $full
    $srcLine = "<!-- 来源 fictional-erotica/$($t.src) · rs-skills-lab/fictional-erotica · MIT -->"
    Set-Content -Path (Join-Path $OutDir "zh/$($t.name).md") -Value ($srcLine + "`n`n" + $r.zh) -Encoding UTF8
    Set-Content -Path (Join-Path $OutDir "en/$($t.name).md") -Value ($srcLine + "`n`n" + $r.en) -Encoding UTF8
    Write-Host ("{0}: zh {1:N0} / en {2:N0} chars" -f $t.name, $r.zh.Length, $r.en.Length)
}
