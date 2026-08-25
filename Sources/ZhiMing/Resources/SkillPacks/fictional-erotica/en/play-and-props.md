<!-- 来源 fictional-erotica/references/play-and-props.md · rs-skills-lab/fictional-erotica · MIT -->

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
