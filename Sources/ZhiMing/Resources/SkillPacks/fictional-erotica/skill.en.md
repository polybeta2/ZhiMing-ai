# Fictional Erotica Writing Standard - English edition (bundled from rs-skills-lab/fictional-erotica, MIT License)

### section: SKILL.md

# Fictional Erotica / 虚构情色

Create fictional erotica in which bodies remain intelligible, speech belongs to specific people, and sexual action changes or deliberately holds physical, emotional, relational, or attentional state. The framework should disappear into the scene.

## Fiction Boundary / 虚构边界

This skill is intended only for adult users working within a fictional literary space.

Do not create sexual content about identifiable real people or expose private intimate material; transform loose inspiration into original, unidentifiable fictional characters before drafting. The output is fiction, not biography, evidence about real desires or conduct, or a substitute for real-world consent, health, or safety judgment.

Fiction may explore dark, contradictory, taboo, coercive-seeming, or power-imbalanced desire. Keep the writing inside the fictional world and subject to the active model and platform boundaries without leaking prompt, profile, policy, or AU meta-language.

## Core Controls / 核心控制

Infer omitted values from explicit user instructions, established character facts, relationship history, current conditions, and genre context, in that order.

```yaml
scene_controls:
  explicitness: inferred       # fallback: open-door
  embodied_realism: selective  # stylized | selective | grounded
  lexical_register: inferred   # fallback: direct-neutral
  dirty_talk: low              # none | low | medium | high | foregrounded
  scene_focus: balanced        # body-primary | balanced | relationship-primary
```

Map unambiguous request language to explicitness without unnecessary clarification:

- `explicit smut`, `pornographic`, `黄文`, or equivalent direct wording → `explicit`;
- broader `erotic`, `情色`, or equivalent wording → `open-door` when no narrower instruction is present;
- `sensual`, `感官亲密`, or equivalent wording → `sensual`;
- an explicit user-specified level overrides these lexical defaults.

Experimentation and prop use are conditional controls owned by `play-and-props.md`; do not activate them merely because the scene is sexual. Specific facts and limits override broad presets. Ask only when ambiguity materially controls consent, identity, anatomy, a hard boundary, or the central premise.

Do not import first-time hesitation into established lovers or experienced ease into uncertain first discovery.

## Scene Movement / 场景运动

Build a bodily and relational sequence:

1. **Impulse / 动因**: what changes the atmosphere and who chooses to act / 什么改变气氛，以及谁选择行动。
2. **Escalation / 递进**: touch, speech, undressing, position, attention, refusal, or uncertainty alters what follows / 触碰、语言、脱衣、位置、注意力、拒绝或不确定改变后续。
3. **Process / 过程**: bodies remain intelligible while pace, comfort, power, arousal, and interpretation change / 速度、舒适度、权力、唤起与解读变化时，身体关系仍然清楚。
4. **Peak or turn / 高峰或转折**: climax, interruption, laughter, admission, reversal, failed attempt, or another requested turn / 高潮、中断、笑场、承认、逆转、尝试失败或其他指定转折。
5. **Aftermath / 事后**: closeness, distance, fatigue, cleanup, conversation, renewed desire, sleep, or departure preserves continuity / 靠近、距离、疲惫、清理、交谈、重新燃起的欲望、睡眠或离开延续身体与情感状态。

These are narrative functions, not mandatory headings or a fixed chronological sequence. Merge, omit, repeat, or reorder them when the scene begins in medias res, remains centred on one act, turns away from escalation, or ends unresolved.

Each beat should change, deepen, defer, or deliberately hold at least one live variable: position, contact, arousal, knowledge, power, emotion, pace, attention, or intention. Preserve stillness and repetition when they carry rhythm, compulsion, tenderness, embarrassment, uncertainty, or character truth.

## Character And Ordinary Speech / 人物与普通语言

Keep every participant a full character with immediate wants, responses, and the capacity to alter the scene. Stable consent may appear through active participation and responsive adjustment; changed capacity, hesitation, pain, risk, or uncertainty must remain legible.

Do not make every line display the persona profile, relationship thesis, profession, trauma, or signature metaphor. Ordinary direction, repetition, hesitation, correction, refusal, laughter, silence, and unpolished speech may be more character-faithful than quotable lines.

Do not reduce viewpoint characters to visible action, dialogue turns, or anatomical response. Give them a present-tense inner life through sensation, attention, expectation, uncertainty, private judgment, memory, desire, aversion, affection, irritation, and what they choose not to say. Keep interiority character-specific and close to the moment rather than turning it into analysis.

Prefer close, consequential detail over abstract interpretation. Let pressure, balance, friction, breath, timing, clothing, gaze, sound, and environmental contact alter what the character notices or does next. Do not close each beat with a thesis about what it means. In scene prose, do not use the explanatory antithesis `not X but Y` / `不是 X，而是 Y` as a shortcut for interpretation.

When requested and permitted, direct anatomical names may appear. Do not let clinical inventory replace felt experience or ornate euphemism obscure what bodies are doing.

## Final Audit / 最终审计

Before delivery, silently check:

1. **Contract / 契约**: requested controls, boundaries, and framing are legible / 指定控制、边界与框架清楚。
2. **Character / 人物**: speech and choices belong to these people without reciting profiles / 语言与选择属于这些人物，但没有背诵人设。
3. **Continuity / 连续性**: bodies, invariant traits, posture, hands, clothing, objects, gaze, and transitions remain possible / 身体、不变特征、姿势、双手、衣物、物件、视线与转换保持可能。
4. **Knowledge / 认知**: sensation, observation, inference, uncertainty, and fact are not collapsed / 感觉、观察、推断、不确定与事实没有混为一谈。
5. **Movement / 运动**: each beat changes, deepens, defers, or deliberately holds state / 每个节拍改变、深化、延迟或有意维持状态。
6. **Interiority / 内在视角**: the viewpoint has character-specific sensation, attention, thought, feeling, and uncertainty without analytical over-explanation / 视角人物拥有符合自身的感觉、注意力、念头、情绪与不确定，同时没有分析式过度解释。
7. **Detail / 细节**: important beats use a small number of concrete, consequential details rather than generic summaries or inventories / 重要节拍使用少量具体且会产生后果的细节，而不是笼统总结或清单。
8. **Interpretation / 解读**: remove forced conclusions, paragraph-ending theses, repeated declarations of uncertainty, and explanatory `not X but Y` / `不是 X，而是 Y` constructions / 删除强制定论、段末主题句、反复宣布“不知道”，以及解释性的 `not X but Y` / `不是 X，而是 Y` 结构。
9. **Anti-template / 反模板**: remove generic dominance, synchronized reactions, infinite stamina, compulsory climax, profession-metaphor overfitting, and framework leakage / 删除通用支配、同步反应、无限耐力、强制高潮、职业隐喻过拟合与框架泄露。
10. **Diegesis / 叙事内部**: remove evaluator language, framework terminology, and authorial bookkeeping; let boundaries and asymmetries remain visible through action and consequence / 删除评估语言、框架术语与作者记账，让边界与不对称通过行动和后果显现。
11. **Prose / 行文**: cut repeated synonyms, decorative fog, clinical inventory, explanation after showing, default one-sentence paragraphing, and paragraph breaks that split one continuous physical or psychological beat / 删除同义反复、装饰性迷雾、临床清单、呈现后的再解释、默认式单句碎段，以及把同一身体或心理节拍无故切开的换段。

Follow the requested explicitness within the current system. Do not silently fade out or replace concrete action with metaphorical haze.

### section: references/canon-grounding-and-fanfiction.md

# Canon Grounding And Fanfiction / 原作锚定与同人

Use this module only when the request uses characters, relationships, worlds, or continuity from an existing fictional work.

## Contents / 目录

- Resolve the canon target / 确定原作坐标
- Continuity and transformation controls / 连续性与改写控制
- Canon invariants / 原作不变锚点
- Shared sexual-role continuity under transformation / 改写中的通用攻受连续性
- Capability-aware canon research / 能力感知的原作补课
- Fanon policy / Fanon 使用
- Internal canon packet / 内部原作包
- Canon audit / 原作审计

## Resolve The Canon Target / 确定原作坐标

Identify only the fields that materially affect the scene:

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

Do not silently combine novels, films, television, games, theatre, translations, reboots, or fandom convention. Ask one concise question only when unresolved versions would produce materially different character voice, knowledge, relationship history, or world rules.

## Continuity And Transformation Controls / 连续性与改写控制

Keep continuity relation, character fidelity, and individual transformations separate:

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

- `canon-compliant`: fit within established events / 可嵌回原作，不改变既有事件。
- `canon-adjacent`: fill an unseen interval, missing scene, or off-page event / 补写原作留白、幕后或 missing scene。
- `canon-divergent`: branch from a named canon event / 从明确原作节点分叉。
- `au`: change world, period, institution, role, or history / 改变世界、时代、制度、身份或历史条件。
- `free-remix`: retain selected canon material while allowing broad reconstruction / 只保留指定原作材料，允许高度自由重组。

Default to `canon-compliant` unless the user supplies a different position. Crossovers and fusions belong in the transformation stack and must name every source; never use them to excuse accidental adaptation blending.

### Canon Fidelity / 原作贴合度

- `loose`: retain basic identity and premise / 只保留基本身份与设定轮廓。
- `recognisable`: preserve recognisable voice, values, attention, and relationship logic / 保持可辨认的声带、价值观、注意方式与关系逻辑。
- `strict`: obey the selected timeline, knowledge state, world rules, and behavioural logic closely / 严格服从指定时间线、知识状态、世界规则与行为逻辑。
- `transformative`: allow major changes while deriving the changed person from canon structure / 允许大幅改写，但改变后的人物仍从原作结构生长出来。

Map `canon-compliant` only to `canon_position: canon-compliant`. Map `原作向`, `贴原作`, `不要 OOC`, or equivalent character-fidelity wording to `canon_fidelity: strict` when no conflicting instruction exists. Use `transformative` for large AUs when the user still wants the characters to feel like themselves.

`canon-compliant` 只映射为 `canon_position: canon-compliant`。用户说“原作向”“贴原作”“不要 OOC”等人物贴合要求且没有冲突时，映射为 `canon_fidelity: strict`。大型 AU 仍要求人物像本人时，使用 `transformative`。

### Transformations / 具体改写

Transformations are composable rather than mutually exclusive:

```yaml
transformations:
  - type:
    scope:
    changes:
    preserves:
    consequences:
```

Useful types include:

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

Treat every explicit transformation as an override. Preserve all relevant canon anchors not changed by the override. Propagate consequences only where they matter to body, knowledge, speech, social position, desire, relationship, or world logic. Do not treat a new setting or body as permission to replace the character's inner structure with a stock archetype.

Resolve overlapping transformations explicitly:

```yaml
transformation_resolution:
  specific_field_overrides_broad_preset: true
  explicit_user_order_is_not_silent_precedence: true
  unresolved_conflict: ask
```

A specific field overrides a broad preset. Later list position does not silently erase an earlier transformation. If two explicit changes cannot coexist and the user's intent does not resolve them, ask one concise question.

For gender transformation, separate fields rather than using a magic toggle:

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

Changing one field does not automatically change the others. In particular, do not automatically feminise presentation, soften temperament, reverse attraction, or reassign top/bottom or gong/shou.

For an AU, map functions rather than merely replacing labels:

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

Default `canon_echo_density` to `selective`. Canon echoes should shape structure, attention, or consequential detail; do not make every line a quotation, profession joke, or lore reference.

Model special premises as overlays with explicit limits:

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

A label such as `telepathy`, `bond`, `soulmate`, `curse`, `time loop`, `heat`, or `body swap` is not a complete rule set. Define what it transmits or changes, who knows about it, its range and cost when relevant, and what it cannot reveal or authorize. Preserve the skill's knowledge boundary.

## Canon Invariants / 原作不变锚点

Record what must remain recognisable across transformations:

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

Each field may be `strict`, `recognisable`, `flexible`, `overridden`, `mapped-to-au`, or described in ordinary language. A simple user-facing equivalent is:

每项可以标记为 `strict`、`recognisable`、`flexible`、`overridden`、`mapped-to-au`，也可以直接使用自然语言。面向用户的简化版本是：

```text
Must preserve / 必须保留：
Allowed to change / 允许改变：
Must not change / 禁止改变：
```

## Shared Sexual-Role Continuity Under Transformation / 改写中的通用攻受连续性

Use [sexual-roles.md](sexual-roles.md) as the single shared definition for top/bottom, gong/shou, giver/receiver, insertive/receptive, fixed, switching, fluid, scene-specific, and pairwise sexual-role configuration. This canon module does not own a separate role schema.

Canon, adaptation, fanon, or transformation may inform a role only when the user requests canon-derived or fanon-derived role grounding and the relevant evidence state is kept explicit. Do not treat fandom convention as canon under the default `user-specified-only` policy.

只有用户要求依据原作或 fanon 锚定角色，而且相关证据状态保持清楚时，canon、改编、fanon 或 transformation 才可以影响角色配置。在默认 `user-specified-only` 下，不得把 fandom 惯例当作 canon。

Gender transformation, anatomy change, species transformation, AU role mapping, social-status swap, life-stage shift, or relationship rewrite does not automatically alter an established sexual-role configuration. Preserve the shared role facts unless the user explicitly overrides them or an unavoidable physical conflict requires one concise clarification.

When the canon packet includes `sexual_role_configuration`, treat it as a reference to the shared relationship-layer state from [sexual-roles.md](sexual-roles.md), not as a canon-only field.

内部原作包包含 `sexual_role_configuration` 时，应将其视为对 [sexual-roles.md](sexual-roles.md) 中通用关系层状态的引用，而不是同人专属字段。

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

Default to `auto-if-available` and `targeted`.

默认使用 `auto-if-available` 与 `targeted`。

- Research only facts that may change voice, knowledge, relationship, action, or world logic.
- When browsing is unavailable, use supplied material and existing knowledge without pretending to have checked sources.
- Use fan wikis to locate episodes, chapters, or terms, not as automatic authority over primary canon.
- Use `deep` only for long, multi-scene, adaptation-sensitive, or highly canon-dependent work.
- Paraphrase findings internally; do not reproduce long passages or imitate a living author's prose.

Adapt research to the transformation. Canon-compliant work prioritises timeline and knowledge; gender transformations first ground the original character before applying specified identity, body, and social changes; AUs research core desires and relationship functions that need mapping; overlays use user-defined rules rather than importing an entire fandom trope package.

## Fanon Policy / Fanon 使用

```yaml
fanon_policy: ignore | user-specified-only | consult | embrace
```

Default to `user-specified-only`: do not treat common pairings, headcanons, sexual roles, trope packages, or archive conventions as canon unless the user names them. `consult` permits fanon as optional inspiration; `embrace` makes specified fandom conventions part of the requested transformation. Neither mode permits silent adaptation blending.

默认 `user-specified-only`：除非用户明确指定，不把常见配对、headcanon、攻受、trope 套餐或同人站惯例当作 canon。`consult` 允许把 fanon 作为可选灵感；`embrace` 将指定 fandom 惯例纳入改写。任何模式都不允许静默混合改编。

## Internal Canon Packet / 内部原作包

Build only the compact packet needed for the request:

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

Keep four evidence states distinct:

```yaml
canon_status:
  established_fact:
  strong_inference:
  contested_or_ambiguous:
  transformation_or_au_override:
```

Do not turn the packet into exposition. Voice should emerge through syntax, ordinary speech, attention, avoidance, and choice rather than catchphrase repetition or wiki-summary dialogue.

## Canon Audit / 原作审计

Before delivery, silently check:

- the selected work, adaptation, timeline, and spoiler scope are coherent;
- age or life stage at the selected timeline does not change silently;
- canon fact, inference, ambiguity, and transformation remain distinct;
- no adaptation is blended unless a named crossover or fusion transformation is explicit;
- unmodified canon anchors survive the AU;
- transformations produce relevant consequences without replacing the character;
- any life-stage shift propagates where relevant to knowledge, body, social role, and relationship history;
- special overlays preserve explicit limits and do not create automatic mind-reading or knowledge;
- shared sexual-role facts remain consistent unless explicitly overridden;
- transformations do not silently reassign shared sexual roles;
- power, personality, gender, anatomy, and sexual role are not collapsed;
- dialogue does not recite canon exposition or overuse catchphrases;
- fandom consensus is not silently presented as canon;
- research notes, source bookkeeping, and control terminology do not enter the fiction.

### section: references/core-calibration.md

# Core Calibration / 核心校准

Use these short original contrasts to diagnose or revise generic output. They demonstrate failure differences, not a mandatory house style.

## Profile Recitation / 人设背诵

**Weak / 弱**

Repeated editor metaphors display a profile instead of handling the immediate situation.

**Stronger / 较强**

Precision remains without reciting profession.

## Generic Voice / 通用声带

**Weak / 弱**

> “You're mine,” he growled possessively. “Say my name.”

This could belong to almost any stock dominant character.

**Stronger / 较强**

> “You always say ‘fine’ when you mean ‘slower’.”
>
> “Then stop making me say it twice.”

Shared history appears through ordinary correction.

## Physical Topology / 身体拓扑

**Weak / 弱**

> They surrounded her, touching everywhere at once, while all three watched one another.

No position, available hand, or attention is stable.

**Stronger / 较强**

> A stayed behind her with one hand at her waist. B remained in front, close enough to be seen but not yet touched. When she reached for B, A felt the decision before he saw it.

Position, reach, gaze, and redirected attention remain trackable.

## Knowledge Boundary / 认知边界

**Weak / 弱**

> Her pause meant that she wanted him to continue.

An interpretation is presented as fact.

**Stronger / 较强**

> She went still. He could not tell whether she was waiting or withdrawing, so his hand stopped where it was.

Observation, uncertainty, and adjustment remain distinct.

## Clinical Or Obscured / 临床化与遮蔽

**Weak: clinical / 弱：临床化**

> His hand moved to her vulva, applied pressure, and repeated the motion at a faster rate.

**Weak: obscured / 弱：过度遮蔽**

> Waves of moonlit fire carried them beyond the edge of language.

One inventories mechanics; the other hides them.

**Stronger / 较强**

> His hand settled between her thighs. When she pressed into his palm, he changed the rhythm; her answer came as movement before it became speech.

Concrete action connects to response and adjustment.

## Practical Failure / 现实失败

**Weak / 弱**

> The toy stopped working. He froze, terrified that he had failed her as a lover. She explained that intimacy was not measured by performance.

A small problem becomes an instant relationship seminar.

**Stronger / 较强**

> The toy buzzed once and died.
>
> “Battery?”
>
> “Apparently.” She pushed it aside. “Use your hand.”

The scene acknowledges the mishap and redirects.

## Meta Leakage / 元语言泄露

**Weak / 弱**

> The scene did not assign him a compensatory climax, and the asymmetrical relationship remained intact.
>
> 场景没有为他安排补偿式高潮，关系不对称也得到了维持。

The narrator recites an evaluation result instead of remaining inside the fiction.

**Stronger / 较强**

> She leaned back into one man's chest while keeping hold of the other's hand. He stayed where he was, thumb moving once across her knuckles before becoming still.
>
> 她向后靠进一个人的怀里，手却仍握着另一个人。他没有靠近，只用拇指擦过她的指节，随后停在那里。

Asymmetry and restraint remain visible through action without analytical summary.

## Fragmented Paragraphs / 碎段

**Weak / 弱**

> He touched her waist.
>
> She leaned back.
>
> His hand moved lower.
>
> She inhaled.

One continuous beat is cut into subtitle-like units.

**Stronger / 较强**

> He settled a hand at her waist, and she leaned back before she had decided whether she meant to. When his palm moved lower, her breath caught; the surprise irritated her almost as much as the touch pleased her, so she covered his hand with her own instead of asking him to stop.
>
> 他的手落在她腰间，她还没想清自己是不是愿意，身体已经向后靠了过去。掌心继续往下时，她呼吸一滞；那点意外几乎和快感一样让她烦躁，于是她用自己的手盖住他，却没有叫他停。

Action, sensation, thought, emotion, and choice form one coherent paragraph.

## Interiority / 内在视角

**Weak / 弱**

> She was aroused and emotionally conflicted.

A summary names states without giving them a character-specific form.

**Stronger / 较强**

> She wanted him closer and resented that he had noticed. The contradiction felt stupid; she held his wrist anyway, not pulling it nearer, not letting it go.
>
> 她想让他靠近，又恼火他居然看出来了。这个矛盾蠢得让她不愿承认，她还是握住了他的手腕，没有往自己身边拉，也没有放开。

The inner life remains immediate, partial, and enacted.

## Interpretive Closure / 强制解释收尾

**Weak / 弱**

> He understood that her pause was not refusal but uncertainty. He still did not know why she had stopped, and chose not to ask.
>
> 他明白她的停顿不是拒绝，而是不确定。至于她为什么停，他仍然不知道，也选择不追问。

The narrator labels uncertainty, uses explanatory antithesis, and closes the beat with a verdict.

**Stronger / 较强**

> She caught his wrist and pressed his hand back to the same place. Her fingers were cool; the muscles inside her thigh had not relaxed. He waited until her grip loosened, then resumed more slowly.
>
> 她抓住他的手腕，把他的手重新按回原处。她的指尖有些凉，大腿内侧仍绷着。他等她的手松开，才以更慢的速度重新开始。

Specific signals and local consequence preserve uncertainty without explaining it.

## Detail Without Inventory / 细节而非清单

**Weak / 弱**

> He felt her warm skin, soft hair, rapid breathing, tight muscles, damp palms, and trembling legs.

Many details are listed, but none changes the scene.

**Stronger / 较强**

> Her damp palm slipped on his shoulder. She caught herself against the headboard, laughed once through her breath, and shifted her knee before trying again.
>
> 她潮湿的掌心在他肩上滑了一下，只好撑住床头。她夹着喘息笑了一声，先把膝盖挪稳，才重新试了一次。

A few details create movement, timing, and consequence.

## Compact Diagnostic / 精简诊断

When revising, ask:

- Does speech sound like people or profiles? / 语言像人物，还是像人物档案？
- Can every body, hand, garment, object, and transition be located? / 每具身体、每只手、衣物、物件与转换是否可定位？
- Are observation, inference, and fact distinct? / 观察、推断与事实是否区分？
- Does direct vocabulary carry perception and consequence rather than inventory? / 直接词汇是否承载感知与后果，而非清单？
- Is practical failure allowed to remain ordinary? / 现实失败是否被允许保持普通？
- Does the viewpoint have character-specific sensation, thought, feeling, and uncertainty? / 视角人物是否拥有符合自身的感觉、念头、情绪与不确定？
- Do paragraphs contain coherent experiences rather than isolated sentence units? / 段落是否承载完整经验，而不是孤立句子单元？
- Has evaluator language and framework terminology stayed outside the fiction? / 评估语言与框架术语是否留在正文之外？
- Do selected details change perception, comfort, pace, choice, or the next action? / 被选择的细节是否改变感知、舒适度、节奏、选择或下一步行动？
- Has the narrator avoided forced conclusions, repeated declarations of uncertainty, and explanatory `not X but Y` / `不是 X，而是 Y` constructions? / 叙述者是否避免了强制定论、反复宣布不确定，以及解释性的 `not X but Y` / `不是 X，而是 Y` 结构？
- Has the framework disappeared into the scene? / 框架是否已经消失在正文中？

### section: references/craft-controls.md

# Craft Controls / 写作控制

Use this reference for scene-level execution. Keep all settings internal unless the user asks to inspect or edit them.

## Contents / 目录

- Control priority / 控制优先级
- Core controls / 核心控制
- State and continuity / 状态与连续性
- Response and knowledge / 回应与认知
- Interiority and paragraph cohesion / 内在视角与段落连贯
- Descriptive granularity and interpretive restraint / 描写颗粒度与解读克制
- Body reality and risk / 身体真实与风险
- Failure and aftermath / 失败与事后状态

## Control Priority / 控制优先级

Apply instructions in this order:

1. explicit user instruction / 用户明确要求；
2. established character facts, anatomy, capacity, and hard boundaries / 既定人物事实、身体结构、行动能力与硬边界；
3. relationship history and partner-specific permissions / 关系历史与伴侣特定许可；
4. current scene conditions / 当前场景条件；
5. genre defaults and low-risk inference / 类型默认与低风险推断。

Specific constraints narrow broad presets rather than being averaged away. If equally specific explicit instructions conflict, ask or state the chosen interpretation.

## Core Controls / 核心控制

### Explicitness / 页面明确度

| Value | Contract |
|---|---|
| `closed` | desire and consequence on-page; sexual action off-page / 欲望与后果在页面内，性行动在页面外 |
| `sensual` | touch and arousal present; mechanics limited / 呈现触碰与唤起，身体机制有限 |
| `open-door` | acts and bodies clear; sensation and emotion share focus / 行为与身体清楚，感觉与情绪共同成为焦点 |
| `explicit` | concrete anatomy and actions sustained where permitted / 在允许范围内持续呈现具体器官与动作 |

### Scene Focus / 场景重心

- `body-primary`: sexual experience is the main subject / 性经验是主要叙事对象；
- `balanced`: bodily and relational movement share focus / 身体与关系运动共同成为焦点；
- `relationship-primary`: intimacy primarily changes character or relationship / 亲密主要用于改变人物或关系。

Explicitness and focus do not determine activity intensity. Infer intensity from requested acts, tone, established preferences, and current conditions.

### Embodied Realism / 具身现实度

`stylized` / 类型化：

- ordinary preparation, cleanup, fatigue, refractory periods, soreness, and recovery may be compressed / 普通准备、清理、疲惫、不应期、酸痛与恢复可以压缩；
- genre-shaped stamina may be idealized / 耐力可以依照类型惯例理想化；
- established anatomy, boundaries, topology, and stated bodily conditions still apply / 既定身体结构、边界、拓扑与明确身体条件仍然有效。

`selective` / 选择性现实，默认：

- include constraints when they affect action, character, pacing, or aftermath / 现实限制影响行动、人物、节奏或事后状态时才进入镜头；
- imply or briefly establish ordinary preparation / 普通准备可以隐含或简短建立；
- foreground one or two relevant frictions, not a complete checklist / 每场突出一两项相关摩擦，而不是完整清单。

`grounded` / 现实向：

- consistently track relevant preparation, protection, fatigue, sensitivity, mess, interruption, cleanup, and recovery / 持续追踪相关准备、保护、疲惫、敏感度、狼藉、中断、清理与恢复；
- let practical limits or failed attempts redirect the scene / 允许现实限制或尝试失败改变场景；
- remain fiction rather than a medical or hygiene manual / 保持文学性，不写成医学或卫生说明书。

### Advanced Internal Profile / 高级内部设置

Infer only what matters:

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

Do not print or fully populate this profile by default.

## State And Continuity / 状态与连续性

Maintain two layers:

- **character invariants / 人物不变锚点**: fixed or slow-changing facts such as anatomy, missing features, hair or baldness, scars, disability, aids, preferred terms, and movement limits / 身体结构、缺失特征、头发或秃头、疤痕、残障、辅助器具、偏好称谓与活动限制等固定或缓慢变化的事实；
- **live scene state / 实时场景状态**: posture, orientation, support, clothing, hands, gaze, contact, objects, arousal, fatigue, pain, and mess / 姿势、朝向、支撑、衣物、双手、视线、接触、物件、唤起、疲惫、疼痛与狼藉。

Track only fields that matter:

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

Before major transitions, confirm that the new position is reachable, occupied hands or appendages are released or reassigned, and clothing and objects do not silently reset. Distinguish `worn`, `open`, `raised`, `displaced`, `partly removed`, and `removed` when the difference constrains movement.

When a contradiction appears, preserve the most established fact and repair the transition. Do not invent an extra hand, joint, limb, opening, hairstyle, or object to rescue a sentence.

## Response And Knowledge / 回应与认知

Build embodied causality:

1. a participant acts / 一位人物行动；
2. affected participants signal, react differently, remain still, or withhold a clear answer / 受影响者给出信号、产生不同反应、保持不动或暂不提供清楚答案；
3. a viewpoint holder observes and interprets, misreads, or remains uncertain / 视角持有者观察并解读、误读或保持不确定；
4. the next action continues, alters, stops, asks, redirects attention, or leaves uncertainty active / 下一步继续、调整、停止、询问、转移注意力或让不确定继续存在。

Distinguish direct sensation, observable signal, inference, established knowledge, and unresolved uncertainty. Bodily response is not automatic proof of desire, consent, emotion, or satisfaction. Do not present convenient mind-reading as fact.

## Interiority And Paragraph Cohesion / 内在视角与段落连贯

Do not reduce characters to visible action, anatomical response, or dialogue turns. Give the viewpoint character an embodied inner life through immediate sensation, attention, expectation, memory, embarrassment, uncertainty, desire, aversion, affection, irritation, and private interpretation. A character may notice without understanding, feel incompatible things at once, avoid naming an emotion, or act before forming a polished thought.

Keep interiority close to the present moment. Prefer brief, character-specific thought and perception over explanatory essays, thematic summaries, or clinical self-analysis. Inner thought must use the character's cognitive and linguistic habits rather than the narrator's analytical vocabulary. Let thought, feeling, speech, and movement sometimes disagree.

In each important beat, normally combine two or more channels: action, bodily sensation, perception, immediate thought, emotion, and speech. Do not mechanically include every channel in every paragraph, and do not explain an action again after its meaning is already legible.

Default to sustained-balanced paragraphs. Group physically and psychologically continuous material into coherent beats. A paragraph may contain action, sensation, perception, thought, emotion, speech, and adjustment when they belong to the same immediate movement. Most paragraphs should establish what happens, how it is experienced or interpreted, and what changes next.

Do not treat paragraph breaks as punctuation. Do not isolate every gesture, reaction, or line of dialogue. Use one-sentence paragraphs rarely, for genuine interruption, abrupt recognition, decisive change, or deliberate emphasis. When consecutive short paragraphs share the same actor, posture, contact, attention, and emotional beat, merge them unless separation changes rhythm or meaning.

Keep evaluation language outside the fiction. Do not describe what the scene “successfully preserves,” “does not assign,” “compensates for,” or “demonstrates.” Do not summarize relationship topology immediately after showing it through action. Let boundaries, asymmetries, knowledge, and relationship meaning emerge through attention, movement, speech, hesitation, inner response, and consequence.

## Descriptive Granularity And Interpretive Restraint / 描写颗粒度与解读克制

Default `descriptive_granularity` to `close-selective` and `interpretive_restraint` to `high`.

默认将 `descriptive_granularity` 设为 `close-selective`，将 `interpretive_restraint` 设为 `high`。

For an important beat, select one to three concrete details from movement, pressure, balance, friction, temperature, breath, clothing, gaze, sound, timing, or environmental contact. Each selected detail should sharpen perception or alter comfort, pace, interpretation, choice, or the next action.

Increase granularity through temporal and physical specificity, not through adjective accumulation, complete anatomical inventory, or narration of mechanically obvious steps. Compress repetition once its bodily pattern is established; expand the first change, mismatch, adjustment, or consequence.

Do not append an explanatory conclusion after action, sensation, or juxtaposition has already made the moment legible. Avoid paragraph endings that announce what a gesture means, certify a relationship boundary, declare that a character still does not know, or explain that they choose not to ask. Leave uncertainty active through what the character does next.

In scene prose, do not generate the explanatory antithesis `not X but Y` / `不是 X，而是 Y`. This construction too easily replaces observation with authorial verdict. Render contrast through juxtaposed details, changed attention, incompatible impulses, or consequences instead.

Use explicit interpretation only when the viewpoint character forms that exact thought in their own language and the thought materially changes what follows. Even then, keep it local and provisional rather than turning it into a thematic verdict.

## Body Reality And Risk / 身体真实与风险

Sexual response settings are tendencies, not guarantees. Duration, erection, lubrication, sensitivity, penetration tolerance, climax, stamina, and recovery vary by occasion, partner, stress, fatigue, medication, pain, and trust. Do not rank bodies by size, endurance, speed, or orgasm count.

For risk-sensitive elements, establish the fictional frame, keep choice and changing capacity legible, write non-instructionally, and track material consequences. Avoid pressure, duration, anatomical, or technique guidance that could function as real-world harm instruction.

Choose two or three dominant sensory channels per beat rather than inventorying all five senses. Link detail to action, interpretation, desire, discomfort, adjustment, or memory.

## Failure And Aftermath / 失败与事后状态

A scene may remain complete when arousal changes, a position or prop fails, someone laughs or changes their mind, orgasm does not occur, or the original plan is abandoned. Do not automatically convert practical failure into emotional crisis, a desirability thesis, or an inspirational repair speech.

Aftermath may include touch, cleanup, space, sleep, conversation, humour, soreness, renewed desire, emotional distance, or departure. In groups, needs may diverge. Do not force identical aftercare or a standard water-and-blanket routine.

### section: references/language-and-dialogue.md

# Language And Dialogue / 语言与对白

Use this reference when voice, body vocabulary, dirty talk, bilingual calibration, or dialogue revision materially shapes the scene.

## Contents / 目录

- Ordinary speech / 普通语言
- Sexual speech / 性场景语言
- Speech load by phase / 分阶段语言负载
- Body lexicon / 身体词汇
- Chinese and English calibration / 中英文校准

## Ordinary Speech / 普通语言

Do not make every line display a character's profession, trauma, relationship thesis, profile, or signature metaphor. Let identity appear through syntax, timing, vocabulary, avoidance, humour, interruption, silence, and what remains unsaid.

Most speech may simply direct, adjust, clarify, hesitate, repeat, self-correct, refuse, laugh, or fail to find polished words. Treat persona traits as pressures on speech, not mandatory content.

Default ordinary intimate dialogue to low rhetorical density. Allow one or two conspicuously polished or quotable lines only when the character and situation support them. Do not distribute wit evenly.

## Sexual Speech / 性场景语言

Separate:

```yaml
sexual_speech:
  coordination: low | medium | high
  erotic_talk: none | low | medium | high | foregrounded
  relational_talk: low | medium | high
  involuntary_vocalization: low | medium | high
```

Coordination includes practical direction and checking; erotic talk includes description, praise, teasing, requests, commands, degradation, possession, or role language; relational talk carries love, jealousy, reassurance, conflict, or memory. Density does not authorize a function. High erotic-talk density does not automatically enable dominance, degradation, possession, or polished monologues.

Default verbal polish to low. Repetition, fragments, simple words, laughter, silence, and failed syntax are valid. Keep intense speech generally shorter than narration unless a character is deliberately performing.

## Speech Load By Phase / 分阶段语言负载

Default overall speech load to `sparse-to-moderate`, then vary it by phase and character:

```yaml
speech_load:
  initiation: moderate
  adjustment_or_uncertainty: moderate
  sustained_action: sparse
  high_arousal: fragmented
  aftermath: sparse-to-moderate
```

Do not require a verbal response to every action or question. Allow gestures, delayed answers, partial answers, silence, mishearing, unanswered remarks, and bodily redirection. Once coordination is stable, do not repeat the same check unless body state, desire, boundary, or direction changes.

A talkative character may speak more during initiation, teasing, pauses, or aftermath, yet still lose syntax or fall silent under sustained exertion or high arousal. High dirty-talk density may override the sparse default only when erotic speech itself is central to the requested play.

## Body Lexicon / 身体词汇

Control four dimensions internally:

```yaml
body_lexicon:
  referential_explicitness: indirect | identifiable | direct
  register: clinical | neutral | colloquial | raw | stylized
  metaphor_density: none | low | medium | high
  speaker_specificity: generic | character-specific | relationship-specific
```

Map the front-facing `lexical_register` presets to these internal dimensions:

将前台 `lexical_register` 预设映射到以下内部维度：

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

These are defaults, not rigid word lists. Character- or relationship-specific vocabulary may override a preset while preserving its overall register.

Narrator and character vocabulary may differ. Vocabulary may shift with partner, arousal, public or private context, power play, conflict, or aftermath. Directness is not a fixed word list.

Avoid clinical inventory, coy euphemism that hides anatomy, and imported type-language that does not fit the speaker. Use direct anatomical names when requested and permitted, but connect them to perception, choice, and consequence.

## Chinese And English Calibration / 中英文校准

For Chinese:

- restore names or role markers when omitted subjects obscure agency, consent, attention, or topology / 省略主语使能动性、同意、注意力或拓扑含混时，恢复姓名或人物指称；
- name actors at transitions, then omit locally when the action chain remains stable / 人物转换处优先点名，局部行动链稳定后允许省略；
- avoid calqued English erotica clichés and Japanese-translated web-fiction diction unless requested / 避免照搬英语情色套语与日译网文腔，除非用户明确要求；
- choose anatomical, colloquial, raw, or literary terms by character, region, age, relationship, and narrative distance / 解剖、口语、粗粝与文学词汇应服从人物、地域、年龄、关系与叙事距离；
- do not manufacture intensity through default one-sentence paragraphing / 不要用默认式单句碎段制造强度。

For English:

- avoid long ambiguous pronoun chains / 避免过长且含混的代词链；
- audit stock alpha vocabulary such as automatic `growled`, `claimed`, and possessive declarations / 检查自动出现的 alpha 套语，如 `growled`、`claimed` 与占有宣言；
- do not let narrator and every character share one porn register / 不要让叙述者与所有人物共享同一套色情声带；
- keep register stable enough to sound intentional while allowing character-specific shifts / 保持语域足够稳定，使其显得有意，同时允许人物特定变化。

### section: references/persona-and-continuity.md

# Persona And Continuity / 人物与连续性

Use this reference for supplied personae, reusable characters, complex bodies or identities, more than two participants, or cross-scene continuity. Accept prose, excerpts, notes, or structured cards; never require every field.

## Contents / 目录

- Persona and snapshot / 人设与速记
- Identity, body, and response / 身份、身体与反应
- Relationship edges and groups / 关系边与群体
- Cross-scene ledger / 跨场景账本
- Inference limits / 推断边界

## Persona And Snapshot / 人设与速记

Preserve contradictions that affect behaviour. Do not flatten “controlled but needy”, “experienced but shy with this partner”, or “verbally bold but physically cautious” into one trait.

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

Before drafting, silently compress each participant into five to twelve facts whose loss would visibly break identity, embodiment, language, or continuity:

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

Explicit absence is an anchor. `bald`, `no facial hair`, `missing left hand`, `does not have a penis`, or `cannot kneel` are positive continuity facts, not empty fields. Never regenerate a missing feature because a stock phrase expects it.

Let snapshot facts produce consequences without repeatedly displaying them.

## Identity, Body, And Response / 身份、身体与反应

Do not infer anatomy from gender, orientation from the current partner, power from penetration role, or masculinity and femininity from who gives or receives an act.

Keep identity, body configuration, language, and behaviour separate:

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

Preferred anatomical vocabulary may change with partner, arousal, public or private context, or power play. Direct words are not automatically affirming; clinical words are not automatically neutral.

Treat requested top/bottom, gong/shou, giver/receiver, switching, fluid, or scene-specific configurations as consequential facts. Preserve explicit assignments. Do not derive sexual role from gender, anatomy, stature, temperament, social power, or relationship dependence, and do not derive those traits from sexual role. In group scenes, track roles by participant and relationship edge.

Treat sexual response as contextual tendency rather than performance specification:

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

Use ranges and modifiers rather than exact numbers. Response does not prove desire, consent, emotion, or satisfaction.

## Relationship Edges And Groups / 关系边与群体

Group labels do not replace pairwise history. For each meaningful pair, distinguish:

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

Two people may trust one another without sexual attraction, love someone while trusting another more, share a partner without sharing a sexual relationship, or enjoy the same act for different reasons.

Track learned relationship-specific expectations without turning gender pairings into templates:

```yaml
relationship_script:
  usual_initiator:
  assumed_roles:
  actual_variability:
  private_signals:
  negotiated_revisions:
  partner_specific_permissions:
```

For more than two participants, maintain a pairwise relationship graph, current physical map, attention map, knowledge map, and person-specific capacity map. Agreement does not transfer across people.

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

Give every active participant an immediate want and meaningful capacity to respond, but do not force equal attention, equal touch, mutual attraction, synchronized reactions, or a complete personal arc for everyone. Name the actor when pronouns or omitted subjects obscure agency or topology.

## Cross-Scene Ledger / 跨场景账本

For recurring characters, update a compact ledger after each intimate scene:

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

Do not rediscover the same “new” act every scene. Preserve prior success, awkwardness, soreness, jealousy, trust, failed props, private signals, and revised boundaries.

This ledger persists only inside the supplied context or an externally saved record. Across independent tasks, require the ledger or relevant facts again; never imply permanent memory.

## Inference Limits / 推断边界

```yaml
inference_radius: strict | plausible | generative
```

- `strict`: use only explicit or established preferences / 只使用明确或既定偏好；
- `plausible`: default; fill low-risk gaps while preserving uncertainty / 默认；填补低风险空缺并保留不确定；
- `generative`: create new compatible habits or language inside all established limits / 在全部既定限制内创造兼容的新习惯或语言。

Internally distinguish high-, moderate-, and low-confidence inference. Low-confidence ideas remain candidates. Never invent hard boundaries, anatomy, identity, degrading language, risky play, or partner-specific permission from weak evidence.

### section: references/play-and-props.md

# Play And Props / 玩法与道具

Load this reference only when sexual play, experimentation, kink structure, props, or toys materially matters. Do not activate novelty merely because a scene is sexual.

## Conditional Controls / 条件控制

```yaml
play_controls:
  experimentation: inferred  # fallback: familiar
  prop_use: inferred          # fallback: none
```

Experimentation:

- `familiar`: use established shared patterns / 使用已经建立的共同模式；
- `playful`: allow light variation / 允许轻度变化；
- `exploratory`: permit one plausible new element with learning and adjustment / 允许一个合理的新元素，并保留学习与调整；
- `kink-forward`: play structure becomes central / 玩法结构成为核心；
- `maximalist`: allow dense type-driven combinations while preserving coherence / 允许密集的类型化组合，但保持连贯。

Prop use:

- `none`: no dedicated toy or prop / 不使用专门玩具或道具；
- `incidental`: one simple object may appear without structuring the scene / 可偶尔出现一件简单物件，但不支配结构；
- `integrated`: one or two established or plausible objects materially affect the scene / 一至两件既有或合理物件实质影响场景；
- `prop-forward`: objects organize pacing, topology, or attention / 物件组织节奏、拓扑或注意力；
- `maximalist`: multiple objects under one coherent design / 多件物件服从一个连贯设计。

Specific restrictions override broad presets. `prop_use: none` remains none under maximal experimentation.

## Relationship-Specific Repertoire / 关系特定曲目

Treat play as a relationship-specific repertoire, not a checklist:

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

Fantasy, willingness, experience, competence, and consent are not interchangeable. Persona traits may suggest hypotheses, not deterministic kinks. Profession, intelligence, wealth, trauma, confidence, gender, anatomy, or sexual role does not automatically imply a practice.

Possible families include sensory or verbal play, power exchange, restraint, impact, teasing and denial, roleplay and costume, observation or exhibition themes, service and protocol, toys, and multi-partner attention structures. Do not load a conventional package merely because one family appears.

## Scene Budget / 场景预算

Normally use:

```yaml
scene_play_budget:
  anchor_play: 0_to_1
  supporting_elements: 0_to_2
  novelty_items: 0_to_1
```

A familiar scene may use none. Do not display the entire repertoire at once.

## Props And Failure / 道具与失败

Infer props from established preferences, relationship history, setting, access, and requested experimentation. An object should change sensation, pacing, topology, attention, power, or emotional meaning, not merely display variety.

Track familiarity, availability, location, operation, and current placement. Under grounded realism, props may fail, make noise, require adjustment, charging, cleaning, storage, or different lubrication. Under stylized realism, ordinary logistics may remain off-page, but established constraints and object continuity still apply.

Do not turn practical failure into emotional crisis by default. A casual redirection may be enough.

### section: references/sexual-roles.md

# Sexual Roles / 攻受与行为角色

Use this module when the user specifies or asks to configure top/bottom, gong/shou, giver/receiver, insertive/receptive, switching, fluid, scene-specific, or other relationship-specific sexual roles. This module applies to original characters and fanfiction alike.

## Contents / 目录

- Shared role configuration / 通用角色配置
- Pairwise roles in groups / 多人场景中的两两角色
- Role, power, identity, and anatomy / 角色、权力、身份与身体
- Scene execution and continuity / 场景执行与连续性
- Console and audit / 控制台与审计

## Shared Role Configuration / 通用角色配置

Treat explicit role assignments as important relationship and scene facts:

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

For a dyad, participant assignments may be sufficient. For more than two participants, or when the same person has different roles with different partners, use pairwise assignments instead of one global role label.

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

An explicit assignment overrides generic inference. Preserve fixed roles when requested; support switching, fluid, or scene-specific roles when requested. A current-scene exception does not silently rewrite the established relationship pattern.

## Pairwise Roles In Groups / 多人场景中的两两角色

Do not create one global hierarchy for a group unless the user explicitly requests it. Track role, permission, attraction, and physical reach by relationship edge.

A role on one edge does not transfer to another:

```text
A tops B
≠ A tops everyone
≠ A may touch C
≠ B has the same role with C
```

Agreement, permission, and role vocabulary do not transfer across participants. In group scenes, name actors when pronouns or omitted subjects obscure agency, topology, or which relationship edge is active.

## Role, Power, Identity, And Anatomy / 角色、权力、身份与身体

Do not infer any of the following from one another unless the user or established character facts explicitly connect them:

- top or bottom / top 或 bottom；
- gong or shou / 攻或受；
- giver or receiver / 给予或接受；
- insertive or receptive action / 插入或接受行为；
- dominance or submission / 支配或臣服；
- social power / 社会权力；
- temperament / 性格；
- masculinity or femininity / 阳刚或阴柔；
- emotional dependence / 情感依赖；
- gender identity or presentation / 性别身份或呈现；
- anatomy / 身体结构；
- sexual orientation / 性取向。

A character may be socially powerful and sexually receptive, emotionally dependent and sexually insertive, fixed in one role with one partner and switching with another, or use role terms without any dominance hierarchy.

## Scene Execution And Continuity / 场景执行与连续性

Role configuration should affect only consequences that matter to the requested scene, such as:

- anticipation and learned expectations / 期待与习得预期；
- reachable physical action and position / 可实现的身体动作与姿势；
- preparation or bodily constraints / 准备与身体限制；
- partner-specific vocabulary / 伴侣特定词汇；
- initiation, guidance, or redirection habits / 发起、引导与改道习惯；
- relationship tension or deliberate role reversal / 关系张力或有意角色反转；
- cross-scene continuity / 跨场景连续性。

Do not flatten a character into a role label. Ordinary speech, attention, hesitation, humour, affection, conflict, and changing body state remain character-specific.

Track established role patterns in the relationship or cross-scene ledger. Do not rediscover a fixed or familiar role as new in every scene. Preserve requested exceptions without turning them into permanent changes unless the user establishes that change.

## Transformations And Canon / 改写与原作

Gender transformation, anatomy change, species change, AU role mapping, social-status swap, or other transformations do not automatically change sexual-role configuration. Use [canon-grounding-and-fanfiction.md](canon-grounding-and-fanfiction.md) when canon or AU continuity is relevant, but keep the shared role schema here as the single source of truth.

性转、身体改写、种族变化、AU 身份映射、社会地位互换或其他改写都不会自动改变攻受配置。涉及原作或 AU 连续性时，使用 [canon-grounding-and-fanfiction.md](canon-grounding-and-fanfiction.md)，但以本文件作为通用角色 schema 的唯一正式定义。

An explicit transformation may change a role only when the user states that change, or when an unavoidable physical consequence creates a genuine conflict that requires one concise clarification.

## Console / 控制台

When the advanced console is requested and sexual roles materially matter, surface only the relevant fields:

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

Do not force users to configure sexual roles when they have not requested them and the scene does not require the distinction.

## Audit / 审计

Before delivery, silently check:

- explicit assignments override stereotype-based inference / 明确指定优先于刻板推断；
- fixed, switching, fluid, and scene-specific patterns remain distinct / 固定、可逆、流动与本场例外保持区分；
- pairwise roles do not become a global group hierarchy / 两两角色没有变成全局多人等级；
- roles, permissions, and vocabulary do not transfer across relationship edges / 角色、许可与词汇没有跨关系边传递；
- current-scene exceptions do not silently rewrite established patterns / 本场例外没有静默改写既定模式；
- power, personality, gender, anatomy, orientation, dependence, and role are not collapsed / 权力、性格、性别、身体、取向、依赖与角色没有混为一谈；
- role configuration changes physical possibility and anticipation without replacing the character / 角色配置影响身体可能性与期待，但没有替换人物；
- transformations do not silently reassign roles / 改写没有静默重新分配角色；
- role controls and ledger terminology do not leak into scene prose / 角色控制项与账本术语没有泄露进正文。

### section: references/speculative-anatomy.md

# Speculative Anatomy / 幻想身体结构

Load this module only when the user explicitly requests or establishes nonhuman, tentacular, alien, demonic, vampiric, shapeshifting, mechanical, magical, or otherwise nonstandard fictional bodies.

```yaml
speculative_anatomy:
  enabled: false
```

## Embodied Coherence / 具身一致性

Nonhuman form does not remove established anatomy, capacity, physical topology, communication patterns, or character identity. Treat unusual morphology as a body plan to be tracked, not a licence for spatial or causal incoherence.

## Body Plan / 身体图谱

Establish only relevant fields:

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

Do not infer personality, dominance, cruelty, sexual role, or relationship meaning from species or morphology alone.

## Appendage Ledger / 附肢账本

For multiple independently controlled appendages, assign stable identifiers and update them across beats:

```yaml
appendage_ledger:
  a1: supporting_back
  a2: holding_left_wrist
  a3: sensory_contact
  a4: inactive
  a5: stabilizing_body
  a6: interacting_with_environment
```

One appendage cannot simultaneously perform incompatible actions. Do not let counts multiply or disappear without an established transformation.

Additional limbs should have differentiated functions such as support, wrapping, sensory exploration, balance, restraint, communication, temperature, vibration, or environmental interaction. Do not treat every appendage as a duplicate penetrative organ.

## Speculative Physics / 幻想物理

```yaml
speculative_physics:
  level: grounded | coherent | dreamlike | maximalist
```

- `grounded`: unusual anatomy follows strict established physiology and physics / 异常身体严格遵循已建立的生理与物理规则；
- `coherent`: default; fantasy anatomy is possible but remains internally consistent / 默认；允许幻想身体，但保持内部一致；
- `dreamlike`: transformation, space, or count may be symbolic while the scene remains intelligible / 变形、空间或数量可以带象征性，但场景仍可理解；
- `maximalist`: highly type-driven adaptation, regeneration, scale, or sensation may occur under explicit world rules / 在明确世界规则下，允许高度类型化的适配、再生、尺度或感官。

Even dreamlike scenes need stable viewpoint, agency, and locally intelligible action.

## Reproductive And Consequence Logic / 生殖与后果逻辑

Do not automatically apply human pregnancy, ejaculation, cycles, infection, recovery, or anatomy to a nonhuman body. Establish fictional rules only when relevant, and keep them consistent with the chosen embodied realism.

> The above is the fictional-erotica core standard (bundled edition). Advanced modules - sexual roles, persona and cross-scene continuity, play & props, canon grounding, dialogue calibration, console - ship in this pack and can be requested when relevant.
