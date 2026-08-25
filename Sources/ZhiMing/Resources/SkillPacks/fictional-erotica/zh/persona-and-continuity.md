<!-- 来源 fictional-erotica/references/persona-and-continuity.md · rs-skills-lab/fictional-erotica · MIT -->

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
