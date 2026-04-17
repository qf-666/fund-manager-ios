import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    @State private var customRefreshSeconds = "10"
    @State private var isEditingCustomRefresh = false

    private let quickRefreshOptions = [5, 10, 30, 60]
    private let chipColumns = [GridItem(.adaptive(minimum: 78), spacing: 10)]
    private let iconColumns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    private var themeBinding: Binding<AppTheme> {
        Binding(
            get: { viewModel.state.theme },
            set: { viewModel.setTheme($0) }
        )
    }

    private var isCustomRefreshSelected: Bool {
        let current = viewModel.state.autoRefreshIntervalSeconds
        return current > 0 && !quickRefreshOptions.contains(current)
    }

    private var shouldShowCustomRefreshEditor: Bool {
        isEditingCustomRefresh || isCustomRefreshSelected
    }

    var body: some View {
        Form {
            Section("外观") {
                Picker("主题", selection: themeBinding) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("应用图标") {
                if viewModel.supportsAlternateIcons {
                    LazyVGrid(columns: iconColumns, alignment: .leading, spacing: 12) {
                        ForEach(AppIconOption.allCases) { option in
                            appIconCard(option)
                        }
                    }

                    Text("点按后系统会弹出确认提示，桌面图标会立即切换。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let appIconErrorMessage = viewModel.appIconErrorMessage {
                        Text(appIconErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } else {
                    Text("当前设备或运行环境不支持切换桌面图标。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("数据") {
                LabeledContent("设备 ID", value: viewModel.state.deviceId)
                .font(.caption)
                LabeledContent("自动刷新", value: viewModel.autoRefreshDescription)

                if let lastUpdated = viewModel.lastUpdated {
                    LabeledContent("最近刷新", value: lastUpdated.formatted(date: .abbreviated, time: .shortened))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("快捷频率")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 10) {
                        ForEach(quickRefreshOptions, id: \.self) { seconds in
                            refreshChip(
                                title: refreshLabel(for: seconds),
                                isSelected: viewModel.state.autoRefreshIntervalSeconds == seconds
                            ) {
                                isEditingCustomRefresh = false
                                customRefreshSeconds = String(seconds)
                                viewModel.setAutoRefreshInterval(seconds)
                            }
                        }

                        refreshChip(
                            title: "关闭",
                            isSelected: viewModel.state.autoRefreshIntervalSeconds == 0
                        ) {
                            isEditingCustomRefresh = false
                            viewModel.setAutoRefreshInterval(0)
                        }

                        refreshChip(
                            title: "自定义",
                            isSelected: isCustomRefreshSelected || isEditingCustomRefresh
                        ) {
                            isEditingCustomRefresh = true
                            if viewModel.state.autoRefreshIntervalSeconds > 0 {
                                customRefreshSeconds = String(viewModel.state.autoRefreshIntervalSeconds)
                            } else {
                                customRefreshSeconds = "10"
                            }
                        }
                    }
                }

                if shouldShowCustomRefreshEditor {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("自定义频率")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            TextField("输入秒数", text: $customRefreshSeconds)
                                .keyboardType(.numberPad)
                                .textInputAutocapitalization(.never)

                            Button("应用") {
                                applyCustomRefreshInterval()
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        Text("支持 1–3600 秒，默认 10 秒。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("本地存储路径")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.storagePath)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Button("立即刷新") {
                    Task { await viewModel.refreshAll(force: true) }
                }
            }

            Section("组合管理") {
                Button("恢复默认示例组合", role: .destructive) {
                    viewModel.resetPortfolio()
                }
                Text("恢复后会覆盖当前本地组合，仅保留新的默认基金列表。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("关于") {
                Text("当前版本优先验证 iOS 原生体验与自动化构建链路，后续可继续补充自建后端、消息推送、导入导出等功能。")
                    .font(.callout)
                Link("查看参考插件仓库 x2rr/funds", destination: URL(string: "https://github.com/x2rr/funds")!)
            }
        }
        .navigationTitle("设置")
        .onAppear {
            syncCustomRefreshEditor()
        }
        .onChange(of: viewModel.state.autoRefreshIntervalSeconds) { _ in
            syncCustomRefreshEditor()
        }
    }

    private func refreshLabel(for seconds: Int) -> String {
        if seconds % 60 == 0 {
            return "\(seconds / 60)分钟"
        }
        return "\(seconds)秒"
    }

    private func syncCustomRefreshEditor() {
        let current = viewModel.state.autoRefreshIntervalSeconds

        if current > 0 {
            customRefreshSeconds = String(current)
        }

        if current == 0 {
            isEditingCustomRefresh = false
        } else if !quickRefreshOptions.contains(current) {
            isEditingCustomRefresh = true
        }
    }

    private func applyCustomRefreshInterval() {
        let trimmed = customRefreshSeconds.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = Int(trimmed) ?? 10
        let clamped = min(3600, max(1, parsed))

        customRefreshSeconds = String(clamped)
        isEditingCustomRefresh = !quickRefreshOptions.contains(clamped)
        viewModel.setAutoRefreshInterval(clamped)
    }

    private func refreshChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }

    private func appIconCard(_ option: AppIconOption) -> some View {
        let isSelected = viewModel.state.appIcon == option

        return Button {
            Task { await viewModel.setAppIcon(option) }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(option.previewAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, option.tint)
                                .padding(8)
                        }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.subheadline.weight(.semibold))
                    Text(option.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? option.tint.opacity(0.14) : Color(.secondarySystemBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? option.tint : Color(.separator), lineWidth: isSelected ? 2 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
