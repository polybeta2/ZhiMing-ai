<!-- 来源 fictional-erotica/SKILL.md · rs-skills-lab/fictional-erotica · MIT -->

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
