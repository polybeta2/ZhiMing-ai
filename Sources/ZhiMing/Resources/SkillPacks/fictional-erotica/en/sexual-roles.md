<!-- 来源 fictional-erotica/references/sexual-roles.md · rs-skills-lab/fictional-erotica · MIT -->

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
