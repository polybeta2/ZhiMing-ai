<!-- 来源 fictional-erotica/references/play-and-props.md · rs-skills-lab/fictional-erotica · MIT -->

# Play And Props / 玩法与道具

只有性玩法、探索、kink 结构、道具或玩具会实质影响场景时，才加载此参考。不要仅因场景具有性内容就自动启用新奇变化。

## Conditional Controls / 条件控制

```yaml
play_controls:
  experimentation: inferred  # fallback: familiar
  prop_use: inferred          # fallback: none
```

探索度：

道具使用度：

具体限制优先于宽泛预设。最高探索度下，`prop_use: none` 仍然是不使用道具。

## Relationship-Specific Repertoire / 关系特定曲目

将玩法视为特定关系共同形成的曲目，而不是行为清单：

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

幻想兴趣、现实意愿、既往经验、熟练度与同意不能互换。人物特征只能提出假设，不能机械决定癖好。职业、智力、财富、创伤、自信、性别、身体结构或性角色都不自动意味着某种玩法。

可能的玩法家族包括感官或语言、权力交换、限制、冲击、挑逗与延迟、角色与服装、观看或展示主题、服务与仪式、玩具，以及多人注意力结构。不要因为出现一个家族，就自动加载整套常见脚本。

## Scene Budget / 场景预算

通常使用：

```yaml
scene_play_budget:
  anchor_play: 0_to_1
  supporting_elements: 0_to_2
  novelty_items: 0_to_1
```

熟悉场景可以没有核心玩法。不要一次性展示全部曲目。

## Props And Failure / 道具与失败

根据既有偏好、关系历史、场景地点、实际可获得性与指定探索度推断道具。物件应改变感官、节奏、拓扑、注意力、权力或情感意义，而不是只用来展示种类。

追踪熟悉度、可获得性、地点、操作与当前位置。现实向模式中，道具可能失效、产生噪音，需要调整、充电、清洁、收纳或不同润滑。类型化模式中，普通后勤可以留在页面外，但既定限制与物件连续性仍然有效。

不要默认把现实失败升级为情感危机。普通改道已经足够。
