import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    private var themeBinding: Binding<AppTheme> {
        Binding(
            get: { viewModel.state.theme },
            set: { viewModel.setTheme($0) }
        )
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

            Section("数据") {
                LabeledContent("设备 ID", value: viewModel.state.deviceId)
                    .font(.caption)
                if let lastUpdated = viewModel.lastUpdated {
                    LabeledContent("最近刷新", value: lastUpdated.formatted(date: .abbreviated, time: .shortened))
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
    }
}
