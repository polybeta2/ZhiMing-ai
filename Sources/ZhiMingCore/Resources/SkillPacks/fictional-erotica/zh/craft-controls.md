<!-- 来源 fictional-erotica/references/craft-controls.md · rs-skills-lab/fictional-erotica · MIT -->

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
