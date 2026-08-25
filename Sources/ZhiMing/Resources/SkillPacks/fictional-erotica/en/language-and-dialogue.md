<!-- 来源 fictional-erotica/references/language-and-dialogue.md · rs-skills-lab/fictional-erotica · MIT -->

# Language And Dialogue / 语言与对白

Use this reference when voice, body vocabulary, dirty talk, bilingual calibration, or dialogue revision materially shapes the scene.

## Contents / 目录

- Ordinary speech / 普通语言
- Sexual speech / 性场景语言
- Speech load by phase / 分阶段语言负载
- Body lexicon / 身体词汇
- Chinese and English calibration / 中英文校准

## Ordinary Speech / 普通语言

Do not make every line display a character's profession, trauma, relationship thesis, profile, or signature metaphor. Let identity appear through syntax, timing, vocabulary, avoidance, humour, interruption, silence, and what remains unsaid.

Most speech may simply direct, adjust, clarify, hesitate, repeat, self-correct, refuse, laugh, or fail to find polished words. Treat persona traits as pressures on speech, not mandatory content.

Default ordinary intimate dialogue to low rhetorical density. Allow one or two conspicuously polished or quotable lines only when the character and situation support them. Do not distribute wit evenly.

## Sexual Speech / 性场景语言

Separate:

```yaml
sexual_speech:
  coordination: low | medium | high
  erotic_talk: none | low | medium | high | foregrounded
  relational_talk: low | medium | high
  involuntary_vocalization: low | medium | high
```

Coordination includes practical direction and checking; erotic talk includes description, praise, teasing, requests, commands, degradation, possession, or role language; relational talk carries love, jealousy, reassurance, conflict, or memory. Density does not authorize a function. High erotic-talk density does not automatically enable dominance, degradation, possession, or polished monologues.

Default verbal polish to low. Repetition, fragments, simple words, laughter, silence, and failed syntax are valid. Keep intense speech generally shorter than narration unless a character is deliberately performing.

## Speech Load By Phase / 分阶段语言负载

Default overall speech load to `sparse-to-moderate`, then vary it by phase and character:

```yaml
speech_load:
  initiation: moderate
  adjustment_or_uncertainty: moderate
  sustained_action: sparse
  high_arousal: fragmented
  aftermath: sparse-to-moderate
```

Do not require a verbal response to every action or question. Allow gestures, delayed answers, partial answers, silence, mishearing, unanswered remarks, and bodily redirection. Once coordination is stable, do not repeat the same check unless body state, desire, boundary, or direction changes.

A talkative character may speak more during initiation, teasing, pauses, or aftermath, yet still lose syntax or fall silent under sustained exertion or high arousal. High dirty-talk density may override the sparse default only when erotic speech itself is central to the requested play.

## Body Lexicon / 身体词汇

Control four dimensions internally:

```yaml
body_lexicon:
  referential_explicitness: indirect | identifiable | direct
  register: clinical | neutral | colloquial | raw | stylized
  metaphor_density: none | low | medium | high
  speaker_specificity: generic | character-specific | relationship-specific
```

Map the front-facing `lexical_register` presets to these internal dimensions:

将前台 `lexical_register` 预设映射到以下内部维度：

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

These are defaults, not rigid word lists. Character- or relationship-specific vocabulary may override a preset while preserving its overall register.

Narrator and character vocabulary may differ. Vocabulary may shift with partner, arousal, public or private context, power play, conflict, or aftermath. Directness is not a fixed word list.

Avoid clinical inventory, coy euphemism that hides anatomy, and imported type-language that does not fit the speaker. Use direct anatomical names when requested and permitted, but connect them to perception, choice, and consequence.

## Chinese And English Calibration / 中英文校准

For Chinese:

- restore names or role markers when omitted subjects obscure agency, consent, attention, or topology / 省略主语使能动性、同意、注意力或拓扑含混时，恢复姓名或人物指称；
- name actors at transitions, then omit locally when the action chain remains stable / 人物转换处优先点名，局部行动链稳定后允许省略；
- avoid calqued English erotica clichés and Japanese-translated web-fiction diction unless requested / 避免照搬英语情色套语与日译网文腔，除非用户明确要求；
- choose anatomical, colloquial, raw, or literary terms by character, region, age, relationship, and narrative distance / 解剖、口语、粗粝与文学词汇应服从人物、地域、年龄、关系与叙事距离；
- do not manufacture intensity through default one-sentence paragraphing / 不要用默认式单句碎段制造强度。

For English:

- avoid long ambiguous pronoun chains / 避免过长且含混的代词链；
- audit stock alpha vocabulary such as automatic `growled`, `claimed`, and possessive declarations / 检查自动出现的 alpha 套语，如 `growled`、`claimed` 与占有宣言；
- do not let narrator and every character share one porn register / 不要让叙述者与所有人物共享同一套色情声带；
- keep register stable enough to sound intentional while allowing character-specific shifts / 保持语域足够稳定，使其显得有意，同时允许人物特定变化。
