# 虚构情色写作规范 · 中文版（fictional-erotica 本地打包，来源 rs-skills-lab/fictional-erotica，MIT License）

### section: SKILL.md

# Fictional Erotica / 虚构情色

创作虚构情色，使身体关系清楚、语言属于具体人物，性行动能够改变或有意维持身体、情绪、关系或注意力状态。让框架消失在正文之中。

## Fiction Boundary / 虚构边界

本 skill 仅供成年用户在虚构文学空间中使用。

不得以可识别的现实人物创作性内容，也不得暴露私人亲密材料；现实灵感必须先转化为无法对应具体个人的原创虚构人物。生成内容属于文学创作，不是现实人物传记或欲望、行为证据，也不能替代现实中的同意、健康或安全判断。

虚构可以探索黑暗、矛盾、禁忌、表面带有强迫意味或权力失衡的欲望。正文应留在虚构世界内部，并遵循当前模型与平台边界，不泄露提示词、人物档案、政策或 AU 元话语。

## Core Controls / 核心控制

遗漏值依次根据用户明确要求、既定人物事实、关系历史、当前状态与类型语境推断。

```yaml
scene_controls:
  explicitness: inferred       # fallback: open-door
  embodied_realism: selective  # stylized | selective | grounded
  lexical_register: inferred   # fallback: direct-neutral
  dirty_talk: low              # none | low | medium | high | foregrounded
  scene_focus: balanced        # body-primary | balanced | relationship-primary
```

根据明确的请求措辞直接推断页面明确度，不进行无必要追问：

探索度与道具使用属于 `play-and-props.md` 的条件控制，不要仅因场景具有性内容就自动启用。具体事实与限制优先于宽泛预设。只有歧义会实质影响同意、身份、身体结构、硬边界或核心前提时才提问。

不要把初次接触的迟疑硬塞进稳定恋人，也不要把熟练自如硬塞进不确定的初次探索。

## Scene Movement / 场景运动

建立身体与关系并行的序列：

这些是叙事功能，不是必须出现的标题或固定时间顺序。场景从中途开始、集中于单一行为、偏离升级路线或以未解决状态结束时，可以合并、省略、重复或调整顺序。

每个节拍应改变、深化、延迟或有意维持至少一个实时变量：位置、接触、唤起、认知、权力、情绪、速度、注意力或意图。停顿与重复若承载节奏、执念、温柔、尴尬、不确定或人物真实，应予保留。

## Character And Ordinary Speech / 人物与普通语言

让每位参与者都是完整人物，拥有即时欲望、回应与改变场景的能力。稳定关系中的同意可以通过主动参与与回应性调整呈现；行动能力变化、迟疑、疼痛、风险或不确定必须清楚可辨。

不要让每句台词都展示人物档案、关系主旨、职业、创伤或标志性比喻。普通指示、重复、犹豫、改口、拒绝、笑、沉默与不够漂亮的话，可能比金句更忠于人物。

不要把视角人物压缩成可观察动作、轮流对白或生理反应。通过当下感觉、注意力、期待、不确定、私人判断、记忆、欲望、排斥、依恋、烦躁与没有说出口的内容，赋予人物内在生活。内心活动应属于具体人物并贴近当下，不要写成分析报告。

优先使用贴近当下、能够产生后果的细节，而不是抽象解释。让压力、平衡、摩擦、呼吸、时机、衣物、视线、声音与环境接触改变人物接下来注意或采取的行动。不要让每个节拍都以意义判决收尾。场景正文中不得用 `not X but Y` / `不是 X，而是 Y` 的解释性对举替代具体呈现。

用户要求且当前系统允许时，可以直接使用器官名称。不要让临床式清单取代感受经验，也不要让华丽委婉语遮蔽身体正在做什么。

## Final Audit / 最终审计

交付前静默检查：

在当前系统允许范围内遵循指定明确度。不要悄悄淡出，也不要用比喻迷雾替代具体行动。

### section: references/canon-grounding-and-fanfiction.md

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

### section: references/core-calibration.md

# Core Calibration / 核心校准

用以下简短原创对照诊断或修订通用化输出。它们展示失败差异，不规定统一文风。

## Profile Recitation / 人设背诵

> “别把关心写成绕路。”
>
> “不是撤稿，换个结尾。”

反复使用编辑隐喻是在展示人设，而不是处理当下情境。

> “这里。”
>
> “再往下一点？”
>
> 她腿一抽，在他手腕上拍了两下。“先别动。”

精确仍然存在，但没有背诵职业。

## Generic Voice / 通用声带

这句话可以属于几乎任何模板化支配者。

共同历史通过普通纠正显现。

## Physical Topology / 身体拓扑

没有人的位置、可用的手或注意力对象稳定。

位置、可触及范围、目光与注意力转移都可追踪。

## Knowledge Boundary / 认知边界

一种解释被写成事实。

观察、不确定与调整保持区分。

## Clinical Or Obscured / 临床化与遮蔽

前者罗列机制，后者遮蔽机制。

具体行动与回应、调整相连。

## Practical Failure / 现实失败

一个小问题被升级为关系研讨会。

场景承认问题，然后普通改道。

## Meta Leakage / 元语言泄露

叙述者在宣读评估结果，而不是留在虚构内部。

不对称与克制通过行动显现，不需要分析性总结。

## Fragmented Paragraphs / 碎段

同一个连续节拍被切成字幕式小块。

动作、感觉、念头、情绪与选择构成一个完整段落。

## Interiority / 内在视角

总结直接命名状态，却没有赋予它属于人物的形式。

内心经验贴近当下、不完全自明，并通过动作继续存在。

## Interpretive Closure / 强制解释收尾

叙述者替不确定命名，使用解释性对举，并以判决式句子封闭节拍。

具体信号与局部后果保留了不确定，不需要解释。

## Detail Without Inventory / 细节而非清单

细节很多，却没有一项改变场景。

少量细节产生了动作、时间与后果。

## Compact Diagnostic / 精简诊断

修订时检查：

### section: references/craft-controls.md

# Craft Controls / 写作控制

用此参考执行场景层控制。除非用户要求查看或修改，否则所有设置均保留在内部。

## Contents / 目录

## Control Priority / 控制优先级

依次应用：

具体限制用于约束宽泛预设，而不是被折中消解。两条同等具体的明确要求冲突时，应询问或说明采用的解释。

## Core Controls / 核心控制

### Explicitness / 页面明确度

| Value | Contract |
|---|---|
| `closed` | desire and consequence on-page; sexual action off-page / 欲望与后果在页面内，性行动在页面外 |
| `sensual` | touch and arousal present; mechanics limited / 呈现触碰与唤起，身体机制有限 |
| `open-door` | acts and bodies clear; sensation and emotion share focus / 行为与身体清楚，感觉与情绪共同成为焦点 |
| `explicit` | concrete anatomy and actions sustained where permitted / 在允许范围内持续呈现具体器官与动作 |

### Scene Focus / 场景重心

页面明确度与场景重心不决定行为强度。强度应由指定行为、基调、既定偏好与当前状态推断。

### Embodied Realism / 具身现实度

### Advanced Internal Profile / 高级内部设置

只推断当前场景需要的内容：

```yaml
advanced_profile:
  camera_distance: external | close | embodied | interior
  action_granularity: compressed | selective | continuous | frame-by-frame
  descriptive_granularity: compressed | selective | close-selective | dense
  interpretive_restraint: low | medium | high
  sensory_weight:
  temporal_profile:
  orgasm_structure:
  mess_visibility: absent | implied | selective | foregrounded
  rhetorical_density: low | intermittent | high
  interiority: sparse | medium | deep
  paragraph_cadence: fragmented | balanced | sustained
  speech_load: sparse | sparse-to-moderate | moderate | dense
  speech_phase_variation: true | false
```

默认不要输出，也不要机械填满这份设置。

## State And Continuity / 状态与连续性

维持两个层级：

只追踪相关字段：

```yaml
live_scene_ledger:
  location_and_spatial_anchors:
  participants:
    - posture:
      orientation:
      support_and_balance:
      clothing:
      hands_or_appendages:
      gaze:
      active_contact:
      current_body_state:
  objects_and_props:
  mess_and_cleanup_state:
  elapsed_time_and_recent_transition:
```

重大转换前，确认新姿势可以从旧姿势到达，被占用的手或附肢已经释放或重新分配，衣物与物件不会悄悄刷新。差异会限制动作时，应区分穿着、敞开、掀起、拨到一侧、部分脱下与完全脱下。

出现矛盾时，保留最牢固的既定事实并修复转换。不要为了挽救一句话而凭空发明额外的手、关节、肢体、开口、发型或物件。

## Response And Knowledge / 回应与认知

建立具身因果：

区分直接感觉、可观察信号、推断、既定认知与未解决的不确定。身体反应不自动证明欲望、同意、情绪或满足。不要把方便叙事的读心写成事实。

## Interiority And Paragraph Cohesion / 内在视角与段落连贯

不要把人物压缩成可观察动作、生理反应或轮流对白。通过即时感觉、注意力、期待、记忆、尴尬、不确定、欲望、排斥、依恋、烦躁与私人解读，赋予视角人物具身的内在生活。人物可以注意到却不理解，可以同时产生互相冲突的感情，可以拒绝给情绪命名，也可以先行动、之后才形成完整念头。

内心活动应贴近当下。优先使用短暂、属于具体人物的念头与感知，避免解释性论文、主题总结或临床式自我分析。内心语言应符合人物自身的认知与语言习惯，而不是借用叙述者的分析词汇。允许念头、情绪、语言与动作彼此不一致。

每个重要节拍通常结合至少两个通道：动作、身体感觉、观察、即时念头、情绪与语言。不要机械地让每段集齐全部通道，也不要在意义已经清楚后再次解释动作。

默认使用持续而均衡的段落。身体与心理上连续的材料应构成完整节拍；同一个即时动作中，可以同时容纳动作、感觉、观察、念头、情绪、语言与调整。多数段落应呈现发生了什么、人物如何感受或理解，以及随后发生了什么变化。

不要把换段当作标点，也不要把每个手势、反应或每句对白分别孤立成段。单句段仅少量用于真正的中断、突然认知、决定性变化或刻意强调。若连续短段拥有同一行动者、姿势、接触、注意力与情绪节拍，除非分段确实改变节奏或意义，否则应优先合并。

让评估语言留在正文之外。不要描述场景“成功维持”“没有被安排”“获得补偿”或“体现”了什么。动作已经呈现关系结构后，不要立刻用分析语言总结关系拓扑。让边界、不对称、认知与关系意义通过注意力、动作、语言、犹豫、内在反应与后果显现。

## Descriptive Granularity And Interpretive Restraint / 描写颗粒度与解读克制

重要节拍中，从动作、压力、平衡、摩擦、温度、呼吸、衣物、视线、声音、时间或环境接触中选择一至三个具体细节。每项被选中的细节都应使感知更清楚，或改变舒适度、节奏、解读、选择或下一步行动。

通过时间与物理上的具体性提高颗粒度，不要依靠堆积形容词、完整身体清单或叙述机械必然的步骤。身体模式已经建立后可以压缩重复，应展开首次变化、不匹配、调整或后果。

动作、感觉或并置已经使当下可辨时，不要追加解释性结论。避免在段末宣布某个动作意味着什么、认证关系边界、声明人物仍然不知道，或解释人物选择不追问。通过人物接下来的行动让不确定继续存在。

场景正文中不得生成解释性对举 `not X but Y` / `不是 X，而是 Y`。这种结构过于容易以作者判决替代观察。应通过并置细节、注意力变化、互相冲突的冲动或后果呈现差异。

只有视角人物确实以自己的语言形成了某个判断，而且该判断实质改变后续时，才明确写出解释。即使如此，也应保持局部和暂定，避免变成主题判决。

## Body Reality And Risk / 身体真实与风险

性反应设置是倾向，不是保证。持续时间、勃起、润滑、敏感度、承受程度、高潮、耐力与恢复会随场合、伴侣、压力、疲惫、药物、疼痛与信任变化。不得按照尺寸、耐力、速度或高潮次数给身体排序。

处理风险敏感元素时，确立虚构框架，使选择与状态变化清楚可辨，以非指导性方式书写，并追踪物质后果。避免可能构成现实伤害指导的力度、时长、解剖或技术细节。

每个节拍选择两到三个主导感官通道，而不是罗列五感。让细节连接行动、解读、欲望、不适、调整或记忆。

## Failure And Aftermath / 失败与事后状态

唤起变化、姿势或道具失败、有人笑场或改变主意、没有高潮、原计划被放弃时，场景仍可完整。不要自动把现实失败升级为情感危机、可欲性论文或励志式修复演讲。

事后状态可以包括触碰、清理、空间、睡眠、交谈、幽默、酸痛、重新燃起的欲望、情感距离或离开。多人场景中的需求可以分化。不要强迫统一照料，也不要套用标准饮水加毯子流程。

### section: references/language-and-dialogue.md

# Language And Dialogue / 语言与对白

人物声带、身体词汇、dirty talk、双语校准或对白修订会实质影响场景时，使用此参考。

## Contents / 目录

## Ordinary Speech / 普通语言

不要让每句台词都展示人物的职业、创伤、关系主旨、人设或标志性比喻。让人物通过句法、时机、词汇、回避、幽默、打断、沉默与未说出口的内容显现。

多数话语可以只负责指示、调整、澄清、犹豫、重复、改口、拒绝、笑或暂时找不到漂亮说法。把人物特征视为影响语言的压力，而不是台词必须明说的内容。

普通亲密对白默认使用低修辞密度。只有人物与情境支持时，才保留一两句明显经过打磨或可摘录的话。不要平均分配机智。

## Sexual Speech / 性场景语言

区分：

```yaml
sexual_speech:
  coordination: low | medium | high
  erotic_talk: none | low | medium | high | foregrounded
  relational_talk: low | medium | high
  involuntary_vocalization: low | medium | high
```

操作性交流包括现实指示与确认；情色语言包括描述、夸奖、逗弄、请求、命令、羞辱、占有或角色语言；关系语言承载爱、嫉妒、安抚、冲突或记忆。密度不授权功能。高密度情色语言不自动启用支配、羞辱、占有或精心打磨的独白。

语言打磨度默认较低。重复、碎句、简单词、笑、沉默与句法失效都有效。除非人物正在刻意表演，高强度状态中的话语通常应短于叙述。

## Speech Load By Phase / 分阶段语言负载

默认总体语言负载为 `sparse-to-moderate`，再根据阶段与人物变化：

```yaml
speech_load:
  initiation: moderate
  adjustment_or_uncertainty: moderate
  sustained_action: sparse
  high_arousal: fragmented
  aftermath: sparse-to-moderate
```

不要让每个动作或问题都获得口头回应。允许手势、延迟回答、只回答一部分、沉默、没有听清、话语落空与身体上的重新引导。操作方式稳定后，不要反复确认同一件事，除非身体状态、欲望、边界或方向发生变化。

爱说话的人物可以在开始、逗弄、停顿或事后说得更多，但持续用力或高度唤起时仍可能失去完整句法或沉默。只有情色语言本身是指定玩法核心时，高密度 dirty talk 才可以覆盖默认的稀疏语言负载。

## Body Lexicon / 身体词汇

内部区分四个维度：

```yaml
body_lexicon:
  referential_explicitness: indirect | identifiable | direct
  register: clinical | neutral | colloquial | raw | stylized
  metaphor_density: none | low | medium | high
  speaker_specificity: generic | character-specific | relationship-specific
```

```yaml
lexical_register_presets:
  indirect-literary:
    referential_explicitness: indirect
    register: stylized
    metaphor_density: low-to-medium
  identifiable-neutral:
    referential_explicitness: identifiable
    register: neutral
    metaphor_density: low
  direct-neutral:
    referential_explicitness: direct
    register: neutral
    metaphor_density: low
  direct-colloquial:
    referential_explicitness: direct
    register: colloquial
    metaphor_density: low
  direct-raw:
    referential_explicitness: direct
    register: raw
    metaphor_density: none-to-low
  stylized:
    referential_explicitness: identifiable
    register: stylized
    metaphor_density: medium
```

这些是默认映射，不是僵硬词表。人物或关系特定词汇可以覆盖预设，但应保持其总体语域。

叙述者与人物可以使用不同词汇。词汇可以随伴侣、唤起、公开或私下情境、权力游戏、冲突或事后状态变化。直白不是固定词表。

避免临床清单、遮蔽身体结构的羞怯委婉语，以及不符合人物的外来类型套语。用户要求且允许时可直接使用器官名称，但应使其连接感知、选择与后果。

## Chinese And English Calibration / 中英文校准

中文重点：

英文重点：

### section: references/persona-and-continuity.md

# Persona And Continuity / 人物与连续性

用户提供人设、可复用人物、复杂身体或身份、两人以上参与者，或要求跨场景连续性时，使用此参考。接受自由叙述、节选、笔记或结构化卡片；不强迫填写所有字段。

## Contents / 目录

## Persona And Snapshot / 人设与速记

保留影响行为的矛盾。不要把“克制却需要依赖”“有经验但面对这个人很害羞”“语言大胆但身体谨慎”压成一个标签。

```yaml
persona:
  name:
  identity:
  public_self:
  private_self:
  voice_fingerprint:
  desires:
  aversions:
  hard_boundaries:
  soft_preferences:
  touch_and_sex_style:
  sexual_history:
  vulnerabilities_and_defenses:
  embodied_constraints:
  current_state:
  continuity_anchors:
```

起草前，为每位参与者静默压缩出五至十二项一旦遗失就会明显破坏身份、身体、语言或连续性的事实：

```yaml
character_snapshot:
  identity_anchor:
  appearance_anchors:
    hair_or_baldness:
    build_and_distinctive_features:
    scars_tattoos_piercings:
  body_anchors:
    anatomy_relevant_to_scene:
    disability_aids_or_missing_parts:
    pain_or_movement_limits:
  language_anchors:
    ordinary_speech_pattern:
    preferred_body_terms:
    prohibited_terms:
  do_not_forget:
```

明确的“不存在”也是锚点。秃头、没有胡须、缺失左手、没有阴茎或无法跪姿，都是积极连续性事实，不是空字段。不要因为套话需要就重新生成缺失特征。

让速记事实产生后果，不要在正文中反复展示。

## Identity, Body, And Response / 身份、身体与反应

不得由性别推断身体结构，不得由当前伴侣推断性取向，不得由插入位置推断权力，也不得把行为中的给予方与接受方自动对应为阳刚或阴柔。

将身份、身体结构、称谓与行为分开：

```yaml
identity:
  gender_identity:
  pronouns:
  orientation:
  preferred_role_terms:
  disliked_labels:

body_configuration:
  anatomy_relevant_to_scene:
  response_patterns:
  reproductive_context:
  disability_or_movement_limits:

language_and_address:
  accepted_terms:
  context_sensitive_terms:
  prohibited_terms:

interaction_profile:
  initiation_style:
  response_to_guidance:
  attention_style:
  performance_anxiety:
  response_to_mistakes:

sexual_role_configuration:
  terminology: top-bottom | gong-shou | giver-receiver | custom
  assignments:
  pattern: fixed | switching | fluid | scene-specific
  current_scene:
  exceptions:
```

偏好的身体词汇可以随伴侣、唤起、公开或私下情境、权力游戏变化。直接词不自动肯定身份，临床词也不自动中性。

把用户指定的 top/bottom、攻受、给予/接受、可逆、流动或本场角色视为会产生后果的事实，并保持明确设定。不得由性别、身体、身高、性格、社会权力或关系依赖推导攻受，也不得由攻受反推这些属性。多人场景按参与者与关系边追踪角色。

将性反应视为受情境影响的倾向，而不是性能参数：

```yaml
sexual_response_profile:
  arousal_onset:
  sensitivity_and_overstimulation:
  lubrication_or_erection_variability:
  orgasm_ease_pathways_and_importance:
  stamina_and_recovery:
  preferred_pace:
  modifiers:
    fatigue:
    stress:
    medication:
    pain:
    trust:
```

使用范围与情境修正，而不是精确数字。身体反应不能证明欲望、同意、情绪或满足。

## Relationship Edges And Groups / 关系边与群体

群体标签不能替代两两历史。对每条重要关系边区分：

```yaml
relationship_edge:
  attraction:
  love:
  trust:
  dependency:
  jealousy:
  loyalty:
  sexual_familiarity:
  shared_repertoire:
  private_shorthand:
  conflict:
  knowledge:
  boundaries:
  desired_and_undesired_meanings:
```

两个人可以彼此信任却没有性吸引，爱一个人却更信任另一个人，共享伴侣却不共享性关系，也可以因为不同意义喜欢同一种行为。

追踪关系中特定的习得预期，但不要把性别组合变成模板：

```yaml
relationship_script:
  usual_initiator:
  assumed_roles:
  actual_variability:
  private_signals:
  negotiated_revisions:
  partner_specific_permissions:
```

两人以上时，维持两两关系图、当前身体地图、注意力地图、信息地图与逐人行动能力地图。同意不能跨人传递。

```yaml
ensemble_scene_state:
  pov_holder:
  focal_edge:
  group_turn:
  attention_pattern:
  entry_state:
  physical_topology:
  knowledge_map:
  exit_state:
```

赋予每位活跃参与者即时欲望与有意义的回应能力，但不要强迫同等注意力、同等触碰、相互吸引、同步反应或人人拥有完整弧线。代词或省略主语使能动性与拓扑含混时，应明确行动者。

## Cross-Scene Ledger / 跨场景账本

反复出现的人物，每个亲密场景后更新精简账本：

```yaml
continuity_ledger:
  established_patterns:
  familiar_recently_explored_and_failed_repertoire:
  evolving_preferences:
  private_words_and_gestures:
  bodily_aftereffects:
  unresolved_emotional_aftereffects:
  changed_boundaries_or_permissions:
  what_this_scene_revealed_or_changed:
```

不要每场重新发现同一个“新玩法”。保留既往成功、尴尬、酸痛、嫉妒、信任、失败道具、私人信号与修订后的边界。

账本只能在已提供的上下文或外部保存记录中延续。跨独立任务时，需要重新提供账本或相关事实；不得暗示模型拥有永久记忆。

## Inference Limits / 推断边界

```yaml
inference_radius: strict | plausible | generative
```

在内部区分高、中、低置信推断。低置信想法保持候选。不得依据薄弱证据擅自生成硬边界、身体结构、身份、羞辱语言、风险玩法或伴侣特定许可。

### section: references/play-and-props.md

# Play And Props / 玩法与道具

只有性玩法、探索、kink 结构、道具或玩具会实质影响场景时，才加载此参考。不要仅因场景具有性内容就自动启用新奇变化。

## Conditional Controls / 条件控制

```yaml
play_controls:
  experimentation: inferred  # fallback: familiar
  prop_use: inferred          # fallback: none
```

探索度：

道具使用度：

具体限制优先于宽泛预设。最高探索度下，`prop_use: none` 仍然是不使用道具。

## Relationship-Specific Repertoire / 关系特定曲目

将玩法视为特定关系共同形成的曲目，而不是行为清单：

```yaml
play_profile:
  repertoire_breadth:
  novelty_appetite:
  technical_experience:
  intensity_preference:
  improvisation:
  ritualization:

play_item:
  fantasy_interest:
  willingness_in_reality:
  prior_experience:
  technical_confidence:
  partner_specific_consent:
  desired_meaning:
  undesired_meaning:
```

幻想兴趣、现实意愿、既往经验、熟练度与同意不能互换。人物特征只能提出假设，不能机械决定癖好。职业、智力、财富、创伤、自信、性别、身体结构或性角色都不自动意味着某种玩法。

可能的玩法家族包括感官或语言、权力交换、限制、冲击、挑逗与延迟、角色与服装、观看或展示主题、服务与仪式、玩具，以及多人注意力结构。不要因为出现一个家族，就自动加载整套常见脚本。

## Scene Budget / 场景预算

通常使用：

```yaml
scene_play_budget:
  anchor_play: 0_to_1
  supporting_elements: 0_to_2
  novelty_items: 0_to_1
```

熟悉场景可以没有核心玩法。不要一次性展示全部曲目。

## Props And Failure / 道具与失败

根据既有偏好、关系历史、场景地点、实际可获得性与指定探索度推断道具。物件应改变感官、节奏、拓扑、注意力、权力或情感意义，而不是只用来展示种类。

追踪熟悉度、可获得性、地点、操作与当前位置。现实向模式中，道具可能失效、产生噪音，需要调整、充电、清洁、收纳或不同润滑。类型化模式中，普通后勤可以留在页面外，但既定限制与物件连续性仍然有效。

不要默认把现实失败升级为情感危机。普通改道已经足够。

### section: references/sexual-roles.md

# Sexual Roles / 攻受与行为角色

用户指定或要求配置 top/bottom、攻受、给予/接受、插入/接受、可逆、流动、本场例外或其他关系特定的性角色时，使用本模块。本模块同时适用于原创人物与同人角色。

## Contents / 目录

## Shared Role Configuration / 通用角色配置

把用户明确指定的攻受与行为角色视为重要的关系及场景事实：

```yaml
sexual_role_configuration:
  terminology: top-bottom | gong-shou | giver-receiver | insertive-receptive | custom
  scope: relationship | participant | current-scene
  assignments:
    A:
    B:
  pattern: fixed | switching | fluid | scene-specific
  current_scene:
  exceptions:
```

两人关系中，逐人 assignments 通常已经足够。参与者超过两人，或同一人物面对不同伴侣拥有不同角色时，应使用两两配置，而不是一套全局标签。

```yaml
pairwise_sexual_roles:
  A-B:
    sexual_relationship: true
    terminology: top-bottom
    pattern: fixed
    assignments:
      A: top
      B: bottom
    current_scene:
    exceptions:

  B-C:
    sexual_relationship: true
    terminology: gong-shou
    pattern: switching
    assignments:
      B:
      C:
    current_scene:

  A-C:
    sexual_relationship: false
    sexual_touch: prohibited
```

用户明确指定时，优先于模型的通用推断。要求固定角色时保持固定；要求可逆、流动或本场例外时按设定执行。本场例外不得静默改写既定关系模式。

## Pairwise Roles In Groups / 多人场景中的两两角色

除非用户明确要求，不要为多人关系建立一套全局等级。按关系边分别追踪角色、许可、吸引与身体可达性。

一条关系边上的角色不会自动转移到另一条关系边：

```text
A tops B
≠ A tops everyone
≠ A may touch C
≠ B has the same role with C
```

同意、许可与角色词汇不能跨人传递。多人场景中，代词或省略主语使能动性、身体拓扑或当前关系边含混时，应明确点名行动者。

## Role, Power, Identity, And Anatomy / 角色、权力、身份与身体

除非用户或既定人物事实明确建立联系，不得让以下项目彼此自动推导：

人物可以拥有较高社会权力却在行为中接受，可以情感依赖却承担插入角色，可以与一个伴侣固定、与另一个伴侣可逆，也可以使用攻受词汇而不存在支配等级。

## Scene Execution And Continuity / 场景执行与连续性

角色配置只应在与当前场景有关时产生后果，例如：

不要把人物压扁成角色标签。普通语言、注意方式、犹豫、幽默、依恋、冲突与身体状态变化仍应属于具体人物。

在关系或跨场景账本中追踪既定角色模式。不要每场重新发现已经固定或熟悉的角色。本场例外应被保留，但除非用户明确建立变化，不得自动变成永久改写。

## Transformations And Canon / 改写与原作

只有用户明确指定角色变化，或身体改写产生无法回避的真实冲突并需要一次简短澄清时，transformation 才能改变角色配置。

## Console / 控制台

用户要求高级控制台且攻受或行为角色会实质影响场景时，只展示相关字段：

```yaml
sexual_role_configuration:
  terminology:
  scope:
  pattern:
  assignments_or_pairwise_edges:
  current_scene:
  exceptions:
  global_hierarchy: none | user-specified
```

用户没有指定，且场景不需要区分时，不得强迫用户配置攻受或行为角色。

## Audit / 审计

交付前静默检查：

### section: references/speculative-anatomy.md

# Speculative Anatomy / 幻想身体结构

只有用户明确要求或已经设定人外、触手、外星、恶魔、吸血鬼、变形、机械、魔法或其他非标准虚构身体时，才加载此模块。

```yaml
speculative_anatomy:
  enabled: false
```

## Embodied Coherence / 具身一致性

非人形态不取消既定身体结构、行动能力、物理拓扑、交流方式或人物身份。应把异常形态作为需要追踪的身体图谱，而不是取消空间与因果一致性的许可。

## Body Plan / 身体图谱

只建立相关字段：

```yaml
speculative_anatomy:
  enabled: true
  species_or_form:
  body_plan:
    humanoid_core:
    additional_appendages:
      type:
      count:
      independent_control:
      dexterity:
  sensory_map:
  physical_properties:
    texture:
    temperature:
    strength:
    flexibility:
  compatibility:
    size_adjustment:
    shape_adjustment:
    regeneration:
  communication:
    speech:
    telepathy:
    tactile_signals:
  reproductive_logic:
  fluid_properties:
  preferred_terms:
```

不得仅由种族或形态推断人物性格、支配性、残酷程度、性角色或关系意义。

## Appendage Ledger / 附肢账本

存在多条可独立控制的附肢时，为其分配稳定编号，并随节拍更新：

```yaml
appendage_ledger:
  a1: supporting_back
  a2: holding_left_wrist
  a3: sensory_contact
  a4: inactive
  a5: stabilizing_body
  a6: interacting_with_environment
```

同一附肢不能同时执行不相容动作。除非已经建立变形规则，不要让数量凭空增加或消失。

额外肢体应承担不同功能，例如支撑、包裹、感官探索、平衡、限制、交流、温度、振动或与环境互动。不要把每条附肢都写成重复的插入器官。

## Speculative Physics / 幻想物理

```yaml
speculative_physics:
  level: grounded | coherent | dreamlike | maximalist
```

即使梦境化场景，也需要稳定视角、能动性与局部可理解的行动。

## Reproductive And Consequence Logic / 生殖与后果逻辑

不要自动把人类怀孕、射精、周期、感染、恢复或身体结构套到非人身体上。只有相关时才建立虚构规则，并与所选具身现实度保持一致。

> 以上为 fictional-erotica 核心规范（本地打包版）。涉及攻受与行为角色、人设与跨场景连续、玩法道具、同人原作锚定、语言对白校准或高级控制台时，对应进阶模块已随包内置，可按需在后续请求中索取。
