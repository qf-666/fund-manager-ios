import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var query = ""

    var body: some View {
        List {
            Section("基金搜索") {
                HStack(spacing: 10) {
                    TextField("输入基金名称、拼音或代码", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit(submitSearch)

                    if viewModel.isSearching {
                        ProgressView()
                            .frame(width: 28)
                    } else {
                        Button("搜索", action: submitSearch)
                            .buttonStyle(.borderedProminent)
                    }
                }

                Text("数据请求直接走东方财富公开接口，适合自选跟踪和轻量持仓管理。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("搜索结果") {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        "输入关键词后开始搜索",
                        systemImage: "magnifyingglass",
                        description: Text("支持基金名称、代码、拼音简称。")
                    )
                } else if viewModel.searchResults.isEmpty && !viewModel.isSearching {
                    Text("暂无匹配结果，换个关键字试试。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.searchResults) { item in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.headline)
                                Text("\(item.code) · \(item.category)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !item.pinyin.isEmpty {
                                    Text(item.pinyin)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            Button("加入") {
                                viewModel.addFund(item)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if !viewModel.sortedHoldings.isEmpty {
                Section("最近已关注") {
                    ForEach(Array(viewModel.sortedHoldings.prefix(5))) { holding in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(holding.name)
                            Text(holding.code)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("添加基金")
    }

    private func submitSearch() {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            viewModel.searchResults = []
            return
        }
        Task {
            await viewModel.search(query: cleaned)
        }
    }
}
