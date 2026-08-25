<!-- 来源 fictional-erotica/references/craft-controls.md · rs-skills-lab/fictional-erotica · MIT -->

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
