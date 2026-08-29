<!-- 来源 fictional-erotica/references/canon-grounding-and-fanfiction.md · rs-skills-lab/fictional-erotica · MIT -->

# Canon Grounding And Fanfiction / 原作锚定与同人

仅在请求使用既有虚构作品的人物、关系、世界或连续性时使用本模块。

## Contents / 目录

## Resolve The Canon Target / 确定原作坐标

只确定会实质影响当前场景的字段：

```yaml
canon_target:
  work:
  franchise:
  medium:
  adaptation:
  timeline_anchor:
  age_or_life_stage_at_timeline:
  spoiler_scope:
  relationship_stage:
```

不要静默混合小说、电影、电视剧、游戏、舞台剧、译本、重启版本或 fandom 惯例。只有版本差异会实质改变人物声带、知识、关系历史或世界规则时，才简短追问一次。

## Continuity And Transformation Controls / 连续性与改写控制

将作品连续性、人物贴合度与具体改写分开控制：

```yaml
fanfiction_controls:
  canon_position: canon-compliant
  canon_fidelity: recognisable
  fanon_policy: user-specified-only
  canon_research:
    mode: auto-if-available
    depth: targeted
  transformations: []
```

### Canon Position / 原作位置

用户没有提供其他位置时，默认 `canon-compliant`。跨作品与融合属于 transformation stack，必须列明每个来源；不得用它们掩盖无意混合改编版本。

### Canon Fidelity / 原作贴合度

### Transformations / 具体改写

具体改写可以叠加，不是互斥选项：

```yaml
transformations:
  - type:
    scope:
    changes:
    preserves:
    consequences:
```

```text
gender_transform
body_transform
setting_au
historical_au
modern_au
role_or_status_swap
relationship_rewrite
timeline_divergence
life_stage_shift
species_transform
supernatural_overlay
special_world_rule
crossover_or_fusion
memory_change
identity_reveal
```

将每项明确改写视为 override；未被改写的相关原作锚点继续有效。只有当改写会影响身体、知识、语言、社会位置、欲望、关系或世界逻辑时，才展开其后果。不得因更换设定或身体就把人物内核替换成类型模板。

明确处理相互重叠的改写：

```yaml
transformation_resolution:
  specific_field_overrides_broad_preset: true
  explicit_user_order_is_not_silent_precedence: true
  unresolved_conflict: ask
```

具体字段优先于宽泛 preset。列表中后写的 transformation 不得静默吃掉前面的改写。两个明确变化无法共存且用户意图不能消解冲突时，简短追问一次。

性转必须拆分字段，不能作为自动联动一切的魔法按钮：

```yaml
gender_transform:
  gender_identity:
  pronouns:
  anatomy:
  presentation:
  social_experience:
  sexuality:
  relationship_role:
```

改变其中一项不自动改变其他项。尤其不得自动女性化外表、软化性格、逆转欲望，或重新分配 top/bottom 与攻受。

AU 应映射原作功能，而不只是替换职业标签：

```yaml
au_profile:
  setting:
  period:
  geography:
  institutions:
  world_rules:
  role_mapping:
  history_mapping:
  relationship_mapping:
  canon_echo_density: minimal | selective | rich | saturated
```

`canon_echo_density` 默认 `selective`。原作回声应影响结构、注意力或有后果的细节，不要让每句话都成为引文、职业双关或设定提示。

特殊设定应作为有明确边界的 overlays：

```yaml
setting_overlays:
  - type:
    rules:
    affected_characters:
    public_knowledge:
    private_knowledge:
    bodily_consequences:
    social_consequences:
    narrative_consequences:
    cannot_do:
```

`telepathy`、联结、灵魂伴侣、诅咒、时间循环、发情机制或身体互换等标签本身不是完整规则。需要说明它传递或改变什么、谁知道、必要时的范围与代价，以及它不能揭示或授权什么，并继续保持认知边界。

## Canon Invariants / 原作不变锚点

记录跨改写仍须可辨认的部分：

```yaml
canon_invariants:
  voice:
  core_values:
  habitual_attention:
  defences_and_vulnerabilities:
  central_relationships:
  knowledge_state:
  appearance:
  anatomy:
  backstory:
```

```text
Must preserve / 必须保留：
Allowed to change / 允许改变：
Must not change / 禁止改变：
```

## Shared Sexual-Role Continuity Under Transformation / 改写中的通用攻受连续性

使用 [sexual-roles.md](sexual-roles.md) 作为 top/bottom、攻受、给予/接受、插入/接受、固定、可逆、流动、本场例外与两两角色配置的唯一通用定义。本同人模块不再维护另一套角色 schema。

性转、身体改写、种族变化、AU 身份映射、社会地位互换、人生阶段变化或关系改写都不会自动改变既定攻受配置。除非用户明确 override，或无法回避的身体冲突需要一次简短澄清，否则继续保留通用角色事实。

## Capability-Aware Canon Research / 能力感知的原作补课

```yaml
canon_research:
  mode: auto-if-available | user-sources-only | no-browse
  depth: none | minimal | targeted | deep
  source_priority:
    - user_supplied_material
    - primary_canon
    - official_reference
    - creator_or_author_commentary
    - reputable_secondary_source
    - fan_wiki_for_navigation_only
```

- 只补充会改变人物声带、知识、关系、行动或世界逻辑的事实。
- 无法浏览时，使用用户材料与已有知识，但不得假装刚刚核查过来源。
- fan wiki 可用于定位集数、章节或关键词，不自动凌驾于原作。
- 只有长篇、多场景、改编敏感或高度依赖原作时才使用 `deep`。
- 在内部转述研究所得，不大段复制原文，也不模仿在世作者的文风。

研究目标应随改写变化。原作向优先核查时间线与知识状态；性转先锚定原作人物，再应用用户指定的身份、身体与社会变化；AU 研究需要映射的核心欲望与关系功能；特殊设定使用用户定义的规则，不自动导入整套 fandom trope。

## Fanon Policy / Fanon 使用

```yaml
fanon_policy: ignore | user-specified-only | consult | embrace
```

## Internal Canon Packet / 内部原作包

只建立当前请求需要的精简原作包：

```yaml
canon_packet:
  identity_and_physical_anchors:
  voice_fingerprint:
  ordinary_speech:
  values_and_drives:
  vulnerabilities_and_defences:
  habitual_attention:
  relationship_edges:
  knowledge_at_timeline:
  relevant_events:
  world_rules:
  canon_invariants:
  sexual_role_configuration:
  fanon_policy:
  avoid_caricaturing_as:
  unresolved_ambiguities:
  transformations_and_au_overrides:
```

始终区分四种信息状态：

```yaml
canon_status:
  established_fact:
  strong_inference:
  contested_or_ambiguous:
  transformation_or_au_override:
```

不要把原作包倒进正文。人物声带应通过句法、普通语言、注意方式、回避与选择显现，而不是复读经典台词或用对白背诵 wiki。

## Canon Audit / 原作审计

交付前静默检查：

- 指定作品、改编、时间线与剧透范围彼此一致；
- 指定时间线中的年龄或人生阶段没有静默漂移；
- 原作事实、推断、歧义与改写保持分离；
- 除非明确加入列明来源的 crossover 或 fusion transformation，不同改编版本没有被混合；
- AU 中未被改写的原作锚点仍然有效；
- 改写产生必要后果，但没有替换人物内核；
- life-stage shift 在相关处传递到知识、身体、社会角色与关系历史；
- 特殊 overlays 保持明确边界，没有制造自动读心或越界知识；
- 通用攻受角色事实保持一致，除非用户明确 override；
- 改写没有静默重新分配通用攻受角色；
- 权力、性格、性别、身体与行为角色没有混为一谈；
- 对白没有背诵原作百科或滥用经典台词；
- fandom 共识没有被静默写成原作事实；
- 研究笔记、来源记账与控制术语没有进入正文。
