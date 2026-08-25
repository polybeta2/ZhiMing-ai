<!-- 来源 fictional-erotica/references/speculative-anatomy.md · rs-skills-lab/fictional-erotica · MIT -->

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
