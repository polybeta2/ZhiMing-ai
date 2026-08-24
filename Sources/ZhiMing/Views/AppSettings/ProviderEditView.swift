import SwiftUI

/// 提供商新增/编辑表单；「测试连接」调用 testConnection()，「获取模型」拉取 /models 列表
struct ProviderEditView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let provider: ProviderConfig?          // nil = 新建

    @State private var name: String
    @State private var baseUrl: String
    @State private var apiKey: String
    @State private var modelName: String
    @State private var temperature: Double
    @State private var maxTokens: Int
    @State private var contextBudgetChars: Int
    @State private var systemPromptExtra: String
    @State private var isDefault: Bool
    @State private var hasExistingKey: Bool
    @State private var testState: TestState = .idle
    @State private var testTask: Task<Void, Never>?
    @State private var showAlert = false
    @State private var alertMessage = ""

    // 模型列表获取（Kelivo 同款）
    @State private var fetchingModels = false
    @State private var fetchedModels: [String] = []
    @State private var showModelPicker = false
    @State private var fetchError: String?
    @State private var fetchTask: Task<Void, Never>?

    enum TestState: Equatable {
        case idle
        case testing
        case success(String)
        case failure(String)
    }

    init(provider: ProviderConfig?) {
        self.provider = provider
        _name = State(initialValue: provider?.name ?? "")
        _baseUrl = State(initialValue: provider?.baseUrl ?? "https://api.openai.com/v1")
        _apiKey = State(initialValue: "")
        _modelName = State(initialValue: provider?.modelName ?? "")
        _temperature = State(initialValue: provider?.temperature ?? 0.8)
        _maxTokens = State(initialValue: provider?.maxTokens ?? 4096)
        _contextBudgetChars = State(initialValue: provider?.contextBudgetChars ?? 12000)
        _systemPromptExtra = State(initialValue: provider?.systemPromptExtra ?? "")
        _isDefault = State(initialValue: provider?.isDefault ?? false)
        _hasExistingKey = State(initialValue: false)
    }

    var body: some View {
        CompatNavigationView {
            Form {
                Section("快捷填充") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppTheme.spacing[1]) {
                            presetButton("OpenAI", url: "https://api.openai.com/v1", model: "gpt-4o-mini")
                            presetButton("DeepSeek", url: "https://api.deepseek.com/v1", model: "deepseek-chat")
                            presetButton("通义千问", url: "https://dashscope.aliyuncs.com/compatible-mode/v1", model: "qwen-plus")
                            presetButton("自定义", url: "", model: "")
                        }
                    }
                }

                Section("接口") {
                    TextField("名称（如：DeepSeek）", text: $name)
                    TextField("Base URL（如 https://api.deepseek.com/v1）", text: $baseUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    SecureField(apiKeyPlaceholder, text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    modelRow
                }

                Section("生成参数") {
                    HStack {
                        Text("温度")
                        Slider(value: $temperature, in: 0...2, step: 0.1)
                        Text(String(format: "%.1f", temperature))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .frame(width: 36)
                    }
                    NumberFieldRow(
                        label: "输出预留 maxTokens",
                        value: $maxTokens,
                        range: 256...1_000_000,
                        step: 512
                    )
                    NumberFieldRow(
                        label: "上下文字符预算",
                        value: $contextBudgetChars,
                        range: 2_000...500_000,
                        step: 4_000
                    )
                }

                Section("附加") {
                    MultilineField(text: $systemPromptExtra, placeholder: "附加系统指令（可选）", minHeight: 56)
                    Toggle("设为默认提供商", isOn: $isDefault)
                }

                Section("连通性") {
                    Button {
                        runConnectionTest()
                    } label: {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                            Text(testState == .testing ? "测试中…" : "测试连接")
                        }
                    }
                    .disabled(testState == .testing)

                    switch testState {
                    case .success(let text):
                        Label("连接成功：\(text)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                            .font(.footnote)
                    case .failure(let message):
                        Label(message, systemImage: "xmark.octagon.fill")
                            .foregroundStyle(Color.red)
                            .font(.footnote)
                    default:
                        EmptyView()
                    }
                }
            }
            .navigationTitle(provider == nil ? "新增提供商" : "编辑提供商")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        testTask?.cancel()
                        fetchTask?.cancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty
                                  || baseUrl.trimmingCharacters(in: .whitespaces).isEmpty
                                  || modelName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("提示", isPresented: $showAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showModelPicker) {
                ModelPickSheet(models: fetchedModels, current: modelName) { selected in
                    modelName = selected
                }
            }
            .onAppear {
                if let p = provider {
                    hasExistingKey = KeychainHelper.load(account: p.apiKeyID) != nil
                }
            }
            .onDisappear {
                testTask?.cancel()
                fetchTask?.cancel()
            }
        }
    }

    /// 模型名输入 + 「获取模型」按钮
    private var modelRow: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing[1]) {
            HStack(spacing: AppTheme.spacing[1]) {
                TextField("模型名（如 deepseek-chat）", text: $modelName)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                Button {
                    fetchModels()
                } label: {
                    if fetchingModels {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("获取模型", systemImage: "arrow.down.circle")
                            .font(.footnote)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(fetchingModels)
            }
            if let fetchError {
                Text(fetchError)
                    .font(.caption2)
                    .foregroundStyle(Color.orange)
            }
        }
    }

    private var apiKeyPlaceholder: String {
        if provider != nil, hasExistingKey {
            return "API Key（留空保持不变）"
        }
        return "API Key"
    }

    private func presetButton(_ title: String, url: String, model: String) -> some View {
        Button {
            if !url.isEmpty { baseUrl = url }
            if !model.isEmpty, modelName.isEmpty { modelName = model }
            if name.isEmpty { name = title }
        } label: {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, AppTheme.spacing[2])
                .padding(.vertical, AppTheme.spacing[1])
                .background(Color.accentColor.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundColor(.accentColor)
    }

    /// 以当前表单值构造客户端（未保存的 Key 也能测试/取模型）
    private func makeClient() -> OpenAICompatibleClient? {
        guard let url = URL(string: baseUrl.trimmingCharacters(in: .whitespaces)), url.scheme != nil else { return nil }
        let key: String
        if !apiKey.isEmpty {
            key = apiKey
        } else if let p = provider, let saved = KeychainHelper.load(account: p.apiKeyID) {
            key = saved
        } else {
            return nil
        }
        return OpenAICompatibleClient(baseUrl: url, apiKey: key, model: modelName.trimmingCharacters(in: .whitespaces))
    }

    // MARK: - 获取模型列表

    private func fetchModels() {
        fetchTask?.cancel()
        guard let client = makeClient() else {
            fetchError = "请先填写有效的 Base URL 与 API Key"
            return
        }
        fetchingModels = true
        fetchError = nil
        fetchTask = Task { @MainActor in
            do {
                let ids = try await client.fetchModelIDs()
                if !Task.isCancelled {
                    if ids.isEmpty {
                        fetchError = "接口返回了空模型列表"
                    } else {
                        fetchedModels = ids
                        showModelPicker = true
                    }
                }
            } catch is CancellationError {
                // 忽略
            } catch {
                if !Task.isCancelled { fetchError = error.localizedDescription }
            }
            if !Task.isCancelled { fetchingModels = false }
        }
    }

    private func runConnectionTest() {
        testTask?.cancel()
        guard let client = makeClient() else {
            testState = .failure("请先填写有效的 Base URL、模型名与 API Key")
            return
        }
        testState = .testing
        testTask = Task { @MainActor in
            do {
                let reply = try await client.testConnection()
                if !Task.isCancelled { testState = .success(reply.isEmpty ? "接口已连通" : reply) }
            } catch {
                if !Task.isCancelled { testState = .failure(error.localizedDescription) }
            }
        }
    }

    private func save() {
        let target = provider ?? ProviderConfig(name: "", baseUrl: "", modelName: "")
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.baseUrl = baseUrl.trimmingCharacters(in: .whitespaces)
        target.modelName = modelName.trimmingCharacters(in: .whitespaces)
        target.temperature = temperature
        target.maxTokens = min(max(maxTokens, 256), 1_000_000)
        target.contextBudgetChars = min(max(contextBudgetChars, 2_000), 500_000)
        let extra = systemPromptExtra.trimmingCharacters(in: .whitespacesAndNewlines)
        target.systemPromptExtra = extra.isEmpty ? nil : extra
        target.isDefault = isDefault

        if provider == nil { store.providers.append(target) }

        // Key 只进 Keychain
        if !apiKey.isEmpty {
            KeychainHelper.save(key: apiKey.trimmingCharacters(in: .whitespaces), account: target.apiKeyID)
        }

        if isDefault {
            for p in store.providers where p.id != target.id { p.isDefault = false }
        } else if !store.providers.contains(where: \.isDefault) {
            target.isDefault = true
        }
        store.save()
        dismiss()
    }
}

/// 可用模型选择列表（带搜索过滤）
private struct ModelPickSheet: View {
    @Environment(\.dismiss) private var dismiss
    let models: [String]
    let current: String
    let onSelect: (String) -> Void

    @State private var query = ""

    private var filtered: [String] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return models }
        return models.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        CompatNavigationView {
            List {
                if filtered.isEmpty {
                    Text("没有匹配的模型")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(filtered, id: \.self) { id in
                    Button {
                        onSelect(id)
                        dismiss()
                    } label: {
                        HStack {
                            Text(id)
                                .font(.subheadline.monospacedDigit())
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            if id == current {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .searchable(text: $query, prompt: "搜索模型名…")
            .navigationTitle("可用模型（\(models.count)）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
