<!-- 来源 fictional-erotica/references/sexual-roles.md · rs-skills-lab/fictional-erotica · MIT -->

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
