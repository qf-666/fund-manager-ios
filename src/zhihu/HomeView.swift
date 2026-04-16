import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var editingHolding: StoredHolding?

    private let gridColumns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        List {
            Section {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    MetricCard(title: "持仓成本", value: DisplayFormatter.currency(viewModel.summary.totalCost), subtitle: "按单位成本 × 持有份额汇总")
                    MetricCard(title: "持仓市值", value: DisplayFormatter.currency(viewModel.summary.totalMarketValue), subtitle: "按已确认净值计算")
                    MetricCard(
                        title: "累计收益",
                        value: DisplayFormatter.signedCurrency(viewModel.summary.totalPnL),
                        subtitle: viewModel.summary.totalReturnPercent.map { DisplayFormatter.percent($0) } ?? "等待持仓数据",
                        tint: viewModel.summary.totalPnL.trendColor
                    )
                    MetricCard(
                        title: "今日收益",
                        value: DisplayFormatter.signedCurrency(viewModel.summary.dailyPnL),
                        subtitle: viewModel.lastUpdated.map { "更新于 \($0.formatted(date: .omitted, time: .shortened))" } ?? "尚未刷新",
                        tint: viewModel.summary.dailyPnL.trendColor
                    )
                }
                .padding(.vertical, 6)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            if !viewModel.indices.isEmpty {
                Section("市场指数") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.indices) { index in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(index.name)
                                        .font(.headline)
                                    Text(DisplayFormatter.price(index.latest))
                                        .font(.title3.weight(.semibold))
                                    Text(DisplayFormatter.percent(index.changePercent))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(index.changePercent.trendColor)
                                    Text("涨跌 \(DisplayFormatter.signedCurrency(index.change))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 180, alignment: .leading)
                                .padding()
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                if viewModel.sortedHoldings.isEmpty {
                    EmptyStateView(
                        "还没有自选基金",
                        systemImage: "star",
                        description: Text("去“搜索”页添加基金，或者在设置中恢复默认示例组合。")
                    )
                } else {
                    ForEach(viewModel.sortedHoldings) { holding in
                        NavigationLink {
                            FundDetailView(holdingID: holding.id)
                        } label: {
                            FundRow(
                                holding: holding,
                                quote: viewModel.quote(for: holding.code),
                                marketValue: viewModel.marketValue(for: holding),
                                totalPnL: viewModel.totalPnL(for: holding),
                                dailyPnL: viewModel.dailyPnL(for: holding)
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("编辑") {
                                editingHolding = holding
                            }
                            .tint(.blue)

                            Button("删除", role: .destructive) {
                                viewModel.deleteHolding(holding)
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button(holding.isPinned ? "取消置顶" : "置顶") {
                                viewModel.togglePin(for: holding)
                            }
                            .tint(.orange)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("我的基金")
                    Spacer()
                    Text("\(viewModel.sortedHoldings.count) 只")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("基金工作台")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await viewModel.refreshAll(force: true) }
                } label: {
                    if viewModel.isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .refreshable {
            await viewModel.refreshAll(force: true)
        }
        .sheet(item: $editingHolding) { holding in
            EditHoldingSheet(holding: holding) { updated in
                viewModel.saveHolding(updated)
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.8)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct FundRow: View {
    let holding: StoredHolding
    let quote: RemoteFundSnapshot?
    let marketValue: Double?
    let totalPnL: Double?
    let dailyPnL: Double?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(holding.name)
                        .font(.headline)
                    if holding.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Text(holding.code)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if holding.hasPosition {
                    Text("持有份额 \(DisplayFormatter.price(holding.shares)) · 单位成本 \(DisplayFormatter.price(holding.costPerUnit))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("仅观察，不计入汇总")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                if let price = quote?.displayPrice {
                    Text(DisplayFormatter.price(price))
                        .font(.headline)
                } else {
                    Text("--")
                        .font(.headline)
                }

                if let changePercent = quote?.displayChangePercent {
                    Text(DisplayFormatter.percent(changePercent))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(changePercent.trendColor)
                } else {
                    Text("未更新")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let marketValue {
                    Text("持仓市值 \(DisplayFormatter.currency(marketValue))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let totalPnL {
                    Text("累计收益 \(DisplayFormatter.signedCurrency(totalPnL))")
                        .font(.caption)
                        .foregroundStyle(totalPnL.trendColor)
                }

                if let dailyPnL {
                    Text("今日收益 \(DisplayFormatter.signedCurrency(dailyPnL))")
                        .font(.caption2)
                        .foregroundStyle(dailyPnL.trendColor)
                }

                if let quote {
                    Text(DisplayFormatter.quoteTimestamp(quote.displayTimestamp, preferTime: !quote.prefersOfficialSnapshot))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
