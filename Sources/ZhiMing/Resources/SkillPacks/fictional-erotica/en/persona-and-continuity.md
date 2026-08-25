<!-- 来源 fictional-erotica/references/persona-and-continuity.md · rs-skills-lab/fictional-erotica · MIT -->

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
