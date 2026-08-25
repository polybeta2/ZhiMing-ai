# SkillPack: fictional-erotica

- 来源：https://github.com/rs-skills-lab/fictional-erotica （MIT License）
- 版本：v1.2.4（main @ 8aff33a，2026-08-02）
- 提取：`Tools/extract-skill.ps1` 把逐段中英对照的原文件按模块拆分为单语言版本：
  - `zh/` 与 `en/` 两个目录，各含 9 个文件（标题/表格/代码块按规则双语言保留）：
    `core`（SKILL.md 核心契约）、`craft-controls`、`persona-and-continuity`、
    `sexual-roles`、`language-and-dialogue`、`play-and-props`、
    `speculative-anatomy`、`canon-grounding-and-fanfiction`、`core-calibration`
- 用途：App 内「R18 增强」开启后：
  1. 按用户输入主语言二选一（禁止中英混合）；
  2. `core` 常驻注入；特化模块由 `PromptLibrary.r18ModuleRoutes` 按
     输入关键词命中动态追加（≤4 个），对应上游 progressive disclosure 设计。
- 更新方式：重新 clone 上游仓库后运行
  `Tools/extract-skill.ps1 -RepoDir <clone> -OutDir Sources/ZhiMing/Resources/SkillPacks/fictional-erotica`
- 注意：本目录（除 README 外）由脚本生成，请勿手工编辑。
