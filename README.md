# 织命 ZhiMing

**本地优先的 AI 长篇小说写作 iOS App** —— 从一句话创意，到设定、章节写作、AI 续写、摘要回注、版本回退的完整闭环。

> 功能精髓取自开源项目 [siming-ai（司命）](https://github.com/teangtang1122/siming-ai)，UI 气质取自开源项目 [Kelivo](https://github.com/Chevey339/kelivo)；本项目为理念移植的独立简化实现，未复用两者代码。

## ✨ 功能

- **作品管理**：作品卡片列表、空白建书 / 一句话立项两种入口
- **立项对话流**：一句话创意 → AI 生成可编辑蓝图（主题/梗概/角色/世界观/卷纲章纲）→ 对话修订 → 一键落库为正式作品
- **设定管理**：角色卡（含「当前状态列」：目标/位置/身体/心理/最近出场 + 剧情参与开关）、世界观条目（分类管理）、卷纲与章细纲
- **章节编辑器**：沉浸正文编辑、字数统计、防抖保存
- **AI 写作**：续写（800/1500/2500 字快捷档）/ 改写 / 润色，SSE 流式输出、随时停止；草稿卡片支持采纳 / 重新生成 / 放弃
- **上下文装配**：三级装配（必需层：风格约束+细纲+正文末尾 800 字；高优先层：最近 3 章摘要+关键事实；可选层：场景角色卡+世界观），字符预算控制，超预算裁剪有提示
- **叙事账本（简化版）**：AI 生成章节摘要与关键事实，下一章续写自动回注
- **版本快照**：AI 采纳前自动快照、手动保存、回退本身也生成新版本（历史永不丢失）
- **模型设置**：任意 OpenAI 兼容接口（OpenAI / DeepSeek / 通义千问 / 自定义中转），API Key 仅存 Keychain
- **界面**：Kelivo 气质聊天页与分组卡片设置页，毛玻璃气泡、深色模式、强调色五选一、生成期间屏幕常亮

## 🧱 技术栈与架构

| 项 | 说明 |
|---|---|
| 语言/UI | Swift 5.9 语义 · SwiftUI · iOS 17+ |
| 架构 | MVVM 四层：View / ViewModel / Service / Model |
| 持久化 | 本地 JSON 文档存储（原子写入 Application Support），零第三方依赖 |
| 网络 | URLSession + AsyncThrowingStream 实现 OpenAI 兼容 SSE 流式调用 |
| 密钥 | Security 框架 Keychain（绝不写 UserDefaults/日志） |

```
Sources/ZhiMing/
├─ App/          # 入口 + 设计令牌（AppTheme）
├─ Models/       # Novel/Volume/Chapter/ChapterSummary/ChapterSnapshot/CharacterCard/WorldEntry/ChatThread/ChatMessage/ProviderConfig + SeedData
├─ Services/     # AppStore(持久层) Keychain LLMClient OpenAICompatibleClient ContextBuilder PromptTemplates SnapshotService
├─ ViewModels/   # WritingSessionViewModel(写作) CreationSessionViewModel(立项状态机)
└─ Views/        # Novels / Chat / Editor / Settings / AppSettings
```

## 📦 在 Windows 上构建（无 Mac）

本项目在 **Windows + WSL2 + xtool** 工具链上开发构建（也可在 macOS/Linux 上用 xtool 构建）：

1. WSL2 安装 Swift 工具链（6.x）与 [xtool](https://github.com/xtool-org/xtool)，并 `xtool sdk install <Xcode.xip>` 安装 darwin SDK；
2. 克隆本仓库后执行：

```powershell
cd ZhiMing
./build.ps1     # xtool dev build --ipa，产物在 xtool/ZhiMing.ipa 并复制到工程根
```

3. 用 [TrollStore](https://github.com/opa334/TrollStore) 或其他侧载方式安装 ipa。

> 图标由 `Tools/gen_icon.py` 程序化生成（纯 Python 标准库手写 PNG）。

## 🚀 快速上手

1. 「设置 → 模型提供商」新增任意 OpenAI 兼容接口（内置 OpenAI / DeepSeek / 通义千问快捷填充），填 API Key 并「测试连接」；
2. 首页右上角 **+**：「一句话立项」输入创意 → AI 生成蓝图 → 在卡片中编辑或对话修订 → 「创建作品」；
3. 进入作品「章节」页签 → 打开章节 → 工具条「续写」开始写作；
4. 写完一章后「生成摘要」建档，下一章续写会自动携带前文摘要与关键事实；
5. 「版本」页签可随时回退到任意历史版本。

首次启动（DEBUG 构建）会注入演示作品《雾港来信》供体验。

## 📝 实施进度

按《织命-iOS实施计划》Phase 0→9 全部完成：

| Phase | 内容 | 状态 |
|---|---|---|
| 0 | 工程基础（目录骨架/设计令牌/Info.plist 定制） | ✅ |
| 1 | 数据层（全部实体 + 演示种子数据） | ✅ |
| 2 | 服务层与连通性验证（Keychain/SSE 客户端/提供商 UI） | ✅ |
| 3 | 作品管理 | ✅ |
| 4 | 设定管理 | ✅ |
| 5 | 章节编辑与 AI 写作闭环 | ✅ |
| 6 | 叙事账本（摘要与回注） | ✅ |
| 7 | 版本快照与回退 | ✅ |
| 8 | 立项对话流 | ✅ |
| 9 | 主题打磨与总验收 | ✅ |

### 与原计划的偏离说明

原计划采用 SwiftData；因 xtool 的 Linux 交叉编译工具链无法加载 SwiftData 闭源宏插件（[xtool-org/xtool#149](https://github.com/xtool-org/xtool/issues/149)），持久层改为等价的零依赖方案：`@Observable` 模型类（字段/关系/级联语义不变）+ `AppStore` JSON 文档原子持久化。服务层、提示词模板、上下文装配逻辑均按原计划落地。

## 🙏 致谢

- **特别感谢 Qwen3.8Max 的辛勤付出** —— 本项目从工程搭建、逐 Phase 编码到最终打包交付，全程由 Qwen3.8Max 高效完成。
- 感谢开源项目 [siming-ai（司命）](https://github.com/teangtang1122/siming-ai) 提供功能蓝本、[Kelivo](https://github.com/Chevey339/kelivo) 提供 UI 蓝本。
- 感谢 [xtool](https://github.com/xtool-org/xtool) 让「无 Mac 构建 iOS 应用」成为现实。

---
*织命 —— 让每一段命运之线，都被好好编织。*
