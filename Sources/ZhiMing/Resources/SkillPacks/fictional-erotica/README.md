# SkillPack: fictional-erotica

- 来源：https://github.com/rs-skills-lab/fictional-erotica （MIT License）
- 版本：v1.2.4（main @ 8aff33a，2026-08-02）
- 提取：`Tools/extract-skill.ps1` 把逐段中英对照的原文件拆分为单语言版本：
  - `skill.zh.md` —— 纯中文指令（标题/表格/代码块按规则双语言保留）
  - `skill.en.md` —— 纯英文指令
- 用途：App 内「R18 增强」开启后，按用户输入主语言二选一注入，禁止中英混合。
- 更新方式：重新 clone 上游仓库后运行
  `Tools/extract-skill.ps1 -RepoDir <clone> -OutDir Sources/ZhiMing/Resources/SkillPacks/fictional-erotica`
- 注意：本目录由脚本生成，请勿手工编辑 skill.zh.md / skill.en.md。
