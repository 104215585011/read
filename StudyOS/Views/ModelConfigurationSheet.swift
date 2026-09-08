import SwiftUI

/// 大模型配置中心弹窗 (ModelConfigurationSheet)
/// 严格遵循 Apple HIG 原生规范，提供 3 标签页结构化多模型管理
public struct ModelConfigurationSheet: View {
    @ObservedObject public var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: ConfigTab = .enabledModels
    
    // 自定义 API 表单字段
    @State private var customProviderKind: ProviderKind = .deepseek
    @State private var customDisplayName: String = "DeepSeek-R1 (自定义)"
    @State private var customEndpoint: String = "https://api.deepseek.com"
    @State private var customModelIdentifier: String = "deepseek-reasoner"
    @State private var customApiKey: String = ""
    @State private var isApiKeyVisible: Bool = false
    @State private var customIsReasoning: Bool = true
    @State private var customContextWindow: String = "64000"
    
    // 握手测试状态
    @State private var isTesting: Bool = false
    @State private var testResult: (success: Bool, message: String)? = nil
    
    public enum ConfigTab: String, CaseIterable, Identifiable {
        case enabledModels = "已启用模型"
        case customAPI = "添加 / 自定义 API"
        case webConnect = "ChatGPT Plus 网页直连"
        
        public var id: String { rawValue }
        
        public var iconName: String {
            switch self {
            case .enabledModels: return "checklist.checked"
            case .customAPI: return "plus.circle"
            case .webConnect: return "safari"
            }
        }
    }
    
    public init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部分段控制器
                Picker("配置选项", selection: $selectedTab) {
                    ForEach(ConfigTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.iconName)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, StudyTheme.Spacing.lg)
                .padding(.vertical, StudyTheme.Spacing.sm)
                
                Divider()
                    .background(StudyTheme.Colors.divider)
                
                // 标签页主体内容
                ScrollView {
                    VStack(spacing: StudyTheme.Spacing.lg) {
                        switch selectedTab {
                        case .enabledModels:
                            enabledModelsSection
                        case .customAPI:
                            customAPISection
                        case .webConnect:
                            webConnectSection
                        }
                    }
                    .padding(StudyTheme.Spacing.lg)
                }
            }
            .background(Color.systemBackground)
            .navigationTitle("大模型配置中心 (Model Hub)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                await viewModel.loadModelProfiles()
            }
        }
    }
    
    // MARK: - 1. 已启用模型列表 (Enabled Models)
    private var enabledModelsSection: some View {
        VStack(alignment: .leading, spacing: StudyTheme.Spacing.md) {
            Text("预置与已接入模型")
                .font(.headline)
            
            Text("支持随时勾选切换正在执行研读、释疑与总结的核心 AI 引擎：")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            ForEach(viewModel.availableProfiles) { profile in
                let isActive = profile.id == viewModel.activeModelProfile?.id
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        // 模型类型图标徽标
                        modelIconBadge(for: profile.providerKind)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(profile.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                if profile.isReasoningModel {
                                    Text("深度思考")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(StudyTheme.Colors.secondary.opacity(0.12))
                                        .foregroundColor(StudyTheme.Colors.secondary)
                                        .clipShape(Capsule())
                                }
                                
                                if isActive {
                                    Text("当前激活")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(StudyTheme.Colors.success.opacity(0.15))
                                        .foregroundColor(StudyTheme.Colors.success)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            HStack(spacing: 8) {
                                Text("模型标识: \(profile.modelIdentifier)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text("\(profile.contextWindowTokens / 1000)k 上下文")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("端点: \(profile.endpoint)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.8))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Spacer()
                        
                        // 勾选与切换按钮
                        Button {
                            Task {
                                await viewModel.switchModel(profile: profile)
                            }
                        } label: {
                            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundColor(isActive ? StudyTheme.Colors.primary : .secondary.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Divider()
                        .background(Color.primary.opacity(0.06))
                    
                    // 底部测试握手按钮
                    HStack {
                        Button {
                            testSpecificProfile(profile)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.horizontal")
                                Text("测试连接握手")
                            }
                            .font(.caption2)
                            .foregroundColor(StudyTheme.Colors.primary)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Text(authDescription(for: profile))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(StudyTheme.Spacing.md)
                .background(Color.primary.opacity(isActive ? 0.05 : 0.02))
                .cornerRadius(StudyTheme.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: StudyTheme.Radius.md)
                        .stroke(isActive ? StudyTheme.Colors.primary.opacity(0.3) : StudyTheme.Colors.border, lineWidth: isActive ? 1.5 : 1)
                )
            }
        }
    }
    
    // MARK: - 2. 添加 / 自定义 API (Custom API)
    private var customAPISection: some View {
        VStack(alignment: .leading, spacing: StudyTheme.Spacing.md) {
            Text("接入自定义 API 引擎")
                .font(.headline)
            
            Text("支持任意 OpenAI Compatible 标准接口、Anthropic、DeepSeek 或自建 Ollama 服务：")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            // 厂商快速预设
            VStack(alignment: .leading, spacing: 6) {
                Text("服务厂商 / 接口规约")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Picker("厂商", selection: $customProviderKind) {
                    Text("DeepSeek 官方开放平台").tag(ProviderKind.deepseek)
                    Text("OpenAI (官方 / 转发中转)").tag(ProviderKind.openai)
                    Text("Anthropic Claude (官方)").tag(ProviderKind.anthropic)
                    Text("Google Gemini (AI Studio)").tag(ProviderKind.gemini)
                    Text("本地局域网 Ollama").tag(ProviderKind.ollama)
                    Text("其他 OpenAI 兼容接口").tag(ProviderKind.custom)
                }
                .pickerStyle(.menu)
                .padding(8)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(StudyTheme.Radius.sm)
                .onChange(of: customProviderKind) { newKind in
                    applyProviderPreset(newKind)
                }
            }
            
            // 表单字段
            Group {
                fieldRow(title: "显示名称", placeholder: "例如: DeepSeek-R1 (主力)", text: $customDisplayName)
                fieldRow(title: "Base URL 接口地址", placeholder: "https://api.deepseek.com", text: $customEndpoint)
                fieldRow(title: "Model ID 标识", placeholder: "deepseek-reasoner", text: $customModelIdentifier)
                fieldRow(title: "上下文窗口 (Tokens)", placeholder: "64000", text: $customContextWindow)
            }
            
            // 深度思考开关
            Toggle(isOn: $customIsReasoning) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("开启深度推理模式 (Reasoning)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("针对 o1、DeepSeek-R1 等输出 CoT 思维链的模型，在侧栏折叠展示思考过程")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
            
            // API Key 输入框 (支持显隐切换)
            VStack(alignment: .leading, spacing: 6) {
                Text("API Key 密钥 (使用 iOS 硬件 Keychain 隔离加密安全存储)")
                    .font(.caption)
                    .fontWeight(.medium)
                
                HStack {
                    if isApiKeyVisible {
                        TextField("sk-...", text: $customApiKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    } else {
                        SecureField("sk-...", text: $customApiKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    Button {
                        isApiKeyVisible.toggle()
                    } label: {
                        Image(systemName: isApiKeyVisible ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(StudyTheme.Radius.sm)
            }
            
            // 握手测试结果反馈条
            if let result = testResult {
                HStack(spacing: 8) {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(result.success ? StudyTheme.Colors.success : StudyTheme.Colors.danger)
                    Text(result.message)
                        .font(.caption)
                        .foregroundColor(result.success ? StudyTheme.Colors.success : StudyTheme.Colors.danger)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background((result.success ? StudyTheme.Colors.success : StudyTheme.Colors.danger).opacity(0.08))
                .cornerRadius(StudyTheme.Radius.sm)
            }
            
            // 动作按钮组
            HStack(spacing: StudyTheme.Spacing.md) {
                // 测试按钮
                Button {
                    performTestConnection()
                } label: {
                    HStack(spacing: 6) {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "bolt.shield")
                        }
                        Text(isTesting ? "握手探测中..." : "测试连接握手")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.08))
                    .foregroundColor(.primary)
                    .cornerRadius(StudyTheme.Radius.md)
                }
                .buttonStyle(.plain)
                .disabled(isTesting || customEndpoint.isEmpty)
                
                // 保存并启用按钮
                Button {
                    saveAndActivateCustomProfile()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                        Text("保存并立即激活")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(StudyTheme.Colors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(StudyTheme.Radius.md)
                }
                .buttonStyle(.plain)
                .disabled(customDisplayName.isEmpty || customEndpoint.isEmpty || customModelIdentifier.isEmpty)
            }
        }
    }
    
    // MARK: - 3. ChatGPT Plus 网页直连与免 Key 方案 (Web Connect & Free Quotas)
    private var webConnectSection: some View {
        VStack(alignment: .leading, spacing: StudyTheme.Spacing.lg) {
            // 卡片 1: ChatGPT Plus
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "safari.fill")
                        .foregroundColor(StudyTheme.Colors.primary)
                        .font(.title3)
                    Text("ChatGPT Plus 网页直连 (免 API Key 消费)")
                        .font(.headline)
                }
                
                Text("针对已经订阅 ChatGPT Plus ($20/月) 的读者，无需额外为 OpenAI API 计费额度充值：")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    guideBullet(title: "会话隔离保障", text: "StudyOS 内置 WebKit 沙盒环境，独立隔离会话凭据，不窃取账号 Cookie。")
                    guideBullet(title: "完整研读体验", text: "支持原生学术 Markdown 格式化排版、公式渲染与多轮上下文追问。")
                    guideBullet(title: "无额外调用成本", text: "完全复用官方 Web 权益与 GPT-4o 算力，适合高频文献精读。")
                }
                .padding(.vertical, 4)
                
                Button {
                    switchToWebSessionProfile()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("一键启用 ChatGPT Plus 网页版")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(StudyTheme.Colors.primary.opacity(0.12))
                    .foregroundColor(StudyTheme.Colors.primary)
                    .cornerRadius(StudyTheme.Radius.md)
                }
                .buttonStyle(.plain)
            }
            .padding(StudyTheme.Spacing.md)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(StudyTheme.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: StudyTheme.Radius.md)
                    .stroke(StudyTheme.Colors.border, lineWidth: 1)
            )
            
            // 卡片 2: Google Gemini 1500次/天 免费额度推荐
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .foregroundColor(StudyTheme.Colors.accent)
                        .font(.title3)
                    Text("Google Gemini 免费额度推荐 (学生与学术首选)")
                        .font(.headline)
                }
                
                Text("若不想付费且没有订阅 Plus，强烈推荐使用 Google AI Studio 提供的官方开发者免费额度：")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    guideBullet(title: "每天 1,500 次免费请求", text: "Gemini 1.5 Pro / Flash 免费档支持高达 15 RPM 与 1,500 RPD 免费请求。")
                    guideBullet(title: "100 万超长上下文", text: "可一次性吞吐整本几十万字英文教材或长篇论文集。")
                    guideBullet(title: "免费获取 Key", text: "登录 Google AI Studio (aistudio.google.com) 点击「Get API key」即可秒级领取。")
                }
                .padding(.vertical, 4)
                
                Button {
                    setupGeminiPreset()
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("快速填入 Gemini 配置模版")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(StudyTheme.Colors.accent.opacity(0.12))
                    .foregroundColor(StudyTheme.Colors.accent)
                    .cornerRadius(StudyTheme.Radius.md)
                }
                .buttonStyle(.plain)
            }
            .padding(StudyTheme.Spacing.md)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(StudyTheme.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: StudyTheme.Radius.md)
                    .stroke(StudyTheme.Colors.border, lineWidth: 1)
            )
        }
    }
    
    // MARK: - 辅助组件与视图函数
    
    private func fieldRow(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            TextField(placeholder, text: text)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(10)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(StudyTheme.Radius.sm)
        }
    }
    
    private func guideBullet(title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .foregroundColor(StudyTheme.Colors.primary)
                .fontWeight(.bold)
            Text("**\(title)**：\(text)")
                .font(.caption)
                .foregroundColor(.primary.opacity(0.85))
        }
    }
    
    private func modelIconBadge(for kind: ProviderKind) -> some View {
        let (icon, color): (String, Color) = {
            switch kind {
            case .deepseek: return ("brain.head.profile", StudyTheme.Colors.secondary)
            case .openai: return ("sparkles", StudyTheme.Colors.primary)
            case .anthropic: return ("text.book.closed.fill", Color.purple)
            case .gemini: return ("sun.max.fill", StudyTheme.Colors.accent)
            case .onDeviceCoreML: return ("cpu.fill", StudyTheme.Colors.success)
            case .chatgptWeb: return ("safari.fill", Color.teal)
            case .ollama: return ("desktopcomputer", Color.orange)
            case .custom: return ("server.rack", Color.gray)
            }
        }()
        
        return Circle()
            .fill(color.opacity(0.12))
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(color)
            )
    }
    
    private func authDescription(for profile: AIModelProfile) -> String {
        switch profile.authMethod {
        case .apiKey: return "Keychain 托管密钥"
        case .webSession: return "Web 网页授权"
        case .none: return "零认证 (离线)"
        }
    }
    
    // MARK: - 业务逻辑动作
    
    private func applyProviderPreset(_ kind: ProviderKind) {
        switch kind {
        case .deepseek:
            customDisplayName = "DeepSeek-R1 (深度推理)"
            customEndpoint = "https://api.deepseek.com"
            customModelIdentifier = "deepseek-reasoner"
            customIsReasoning = true
            customContextWindow = "64000"
        case .openai:
            customDisplayName = "OpenAI GPT-4o"
            customEndpoint = "https://api.openai.com/v1"
            customModelIdentifier = "gpt-4o"
            customIsReasoning = false
            customContextWindow = "128000"
        case .anthropic:
            customDisplayName = "Claude 3.5 Sonnet"
            customEndpoint = "https://api.anthropic.com/v1"
            customModelIdentifier = "claude-3-5-sonnet-20241022"
            customIsReasoning = false
            customContextWindow = "200000"
        case .gemini:
            customDisplayName = "Gemini 1.5 Pro"
            customEndpoint = "https://generativelanguage.googleapis.com/v1beta/openai"
            customModelIdentifier = "gemini-1.5-pro"
            customIsReasoning = false
            customContextWindow = "1000000"
        case .ollama:
            customDisplayName = "本地 Ollama (Qwen2.5)"
            customEndpoint = "http://localhost:11434/v1"
            customModelIdentifier = "qwen2.5:7b"
            customIsReasoning = false
            customContextWindow = "32000"
        case .custom:
            customDisplayName = "自定义兼容模型"
            customEndpoint = "https://your-custom-proxy.com/v1"
            customModelIdentifier = "custom-model"
            customIsReasoning = false
            customContextWindow = "64000"
        case .chatgptWeb, .onDeviceCoreML:
            break
        }
    }
    
    private func performTestConnection() {
        isTesting = true
        testResult = nil
        
        let tempProfile = AIModelProfile(
            id: UUID().uuidString,
            displayName: customDisplayName,
            providerKind: customProviderKind,
            endpoint: customEndpoint,
            modelIdentifier: customModelIdentifier,
            isReasoningModel: customIsReasoning,
            authMethod: .apiKey,
            contextWindowTokens: Int(customContextWindow) ?? 64000
        )
        
        Task {
            do {
                let result = try await viewModel.testConnection(profile: tempProfile, apiKey: customApiKey)
                self.isTesting = false
                self.testResult = (success: result.success, message: result.message)
            } catch {
                self.isTesting = false
                self.testResult = (success: false, message: error.localizedDescription)
            }
        }
    }
    
    private func testSpecificProfile(_ profile: AIModelProfile) {
        Task {
            do {
                let result = try await viewModel.testConnection(profile: profile, apiKey: nil)
                viewModel.displayToast("握手结果: \(result.message)")
            } catch {
                viewModel.displayToast("探测异常: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveAndActivateCustomProfile() {
        let newProfile = AIModelProfile(
            id: "custom_\(UUID().uuidString.prefix(8))",
            displayName: customDisplayName,
            providerKind: customProviderKind,
            endpoint: customEndpoint,
            modelIdentifier: customModelIdentifier,
            isReasoningModel: customIsReasoning,
            authMethod: .apiKey,
            contextWindowTokens: Int(customContextWindow) ?? 64000,
            isDefault: true
        )
        
        Task {
            do {
                try await viewModel.saveCustomModelProfile(newProfile, apiKey: customApiKey)
                await viewModel.switchModel(profile: newProfile)
                self.selectedTab = .enabledModels
            } catch {
                viewModel.displayToast("保存失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func switchToWebSessionProfile() {
        if let webProfile = viewModel.availableProfiles.first(where: { $0.providerKind == .chatgptWeb }) {
            Task {
                await viewModel.switchModel(profile: webProfile)
                dismiss()
            }
        } else {
            viewModel.displayToast("ChatGPT Plus 网页直连配置已默认就绪")
        }
    }
    
    private func setupGeminiPreset() {
        self.customProviderKind = .gemini
        applyProviderPreset(.gemini)
        self.selectedTab = .customAPI
    }
}
