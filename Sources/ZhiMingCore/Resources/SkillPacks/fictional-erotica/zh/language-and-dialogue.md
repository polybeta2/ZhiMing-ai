<!-- 来源 fictional-erotica/references/language-and-dialogue.md · rs-skills-lab/fictional-erotica · MIT -->

# Language And Dialogue / 语言与对白

人物声带、身体词汇、dirty talk、双语校准或对白修订会实质影响场景时，使用此参考。

## Contents / 目录

## Ordinary Speech / 普通语言

不要让每句台词都展示人物的职业、创伤、关系主旨、人设或标志性比喻。让人物通过句法、时机、词汇、回避、幽默、打断、沉默与未说出口的内容显现。

多数话语可以只负责指示、调整、澄清、犹豫、重复、改口、拒绝、笑或暂时找不到漂亮说法。把人物特征视为影响语言的压力，而不是台词必须明说的内容。

普通亲密对白默认使用低修辞密度。只有人物与情境支持时，才保留一两句明显经过打磨或可摘录的话。不要平均分配机智。

## Sexual Speech / 性场景语言

区分：

```yaml
sexual_speech:
  coordination: low | medium | high
  erotic_talk: none | low | medium | high | foregrounded
  relational_talk: low | medium | high
  involuntary_vocalization: low | medium | high
```

操作性交流包括现实指示与确认；情色语言包括描述、夸奖、逗弄、请求、命令、羞辱、占有或角色语言；关系语言承载爱、嫉妒、安抚、冲突或记忆。密度不授权功能。高密度情色语言不自动启用支配、羞辱、占有或精心打磨的独白。

语言打磨度默认较低。重复、碎句、简单词、笑、沉默与句法失效都有效。除非人物正在刻意表演，高强度状态中的话语通常应短于叙述。

## Speech Load By Phase / 分阶段语言负载

默认总体语言负载为 `sparse-to-moderate`，再根据阶段与人物变化：

```yaml
speech_load:
  initiation: moderate
  adjustment_or_uncertainty: moderate
  sustained_action: sparse
  high_arousal: fragmented
  aftermath: sparse-to-moderate
```

不要让每个动作或问题都获得口头回应。允许手势、延迟回答、只回答一部分、沉默、没有听清、话语落空与身体上的重新引导。操作方式稳定后，不要反复确认同一件事，除非身体状态、欲望、边界或方向发生变化。

爱说话的人物可以在开始、逗弄、停顿或事后说得更多，但持续用力或高度唤起时仍可能失去完整句法或沉默。只有情色语言本身是指定玩法核心时，高密度 dirty talk 才可以覆盖默认的稀疏语言负载。

## Body Lexicon / 身体词汇

内部区分四个维度：

```yaml
body_lexicon:
  referential_explicitness: indirect | identifiable | direct
  register: clinical | neutral | colloquial | raw | stylized
  metaphor_density: none | low | medium | high
  speaker_specificity: generic | character-specific | relationship-specific
```

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

这些是默认映射，不是僵硬词表。人物或关系特定词汇可以覆盖预设，但应保持其总体语域。

叙述者与人物可以使用不同词汇。词汇可以随伴侣、唤起、公开或私下情境、权力游戏、冲突或事后状态变化。直白不是固定词表。

避免临床清单、遮蔽身体结构的羞怯委婉语，以及不符合人物的外来类型套语。用户要求且允许时可直接使用器官名称，但应使其连接感知、选择与后果。

## Chinese And English Calibration / 中英文校准

中文重点：

英文重点：
