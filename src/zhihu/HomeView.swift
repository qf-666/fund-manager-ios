import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var editingHolding: StoredHolding?

    var body: some View {
        List {
            if !viewModel.indices.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.indices) { index in
                                MarketIndexCard(index: index)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            Section {
                PortfolioSummaryCard(
                    totalMarketValue: viewModel.summary.totalMarketValue,
                    totalPnL: viewModel.summary.totalPnL,
                    dailyPnL: viewModel.summary.dailyPnL,
                    totalReturnPercent: viewModel.summary.totalReturnPercent,
                    updatedAt: viewModel.lastUpdated
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section {
                if viewModel.sortedHoldings.isEmpty {
                    EmptyStateView(
                        "还没有自选基金",
                        systemImage: "star",
                        description: Text("去“搜索”页添加基金，或在设置里恢复默认示例组合。")
                    )
                } else {
                    ForEach(viewModel.sortedHoldings) { holding in
                        NavigationLink {
                            FundDetailView(holdingID: holding.id)
                        } label: {
                            HoldingOverviewRow(
                                holding: holding,
                                quote: viewModel.quote(for: holding.code),
                                marketValue: viewModel.marketValue(for: holding),
                                totalPnL: viewModel.totalPnL(for: holding),
                                dailyPnL: viewModel.dailyPnL(for: holding),
                                totalReturnPercent: viewModel.returnPercent(for: holding)
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
            } footer: {
                Text("列表信息结构对齐插件首页：估算净值、持有额、持有收益、收益率、涨跌幅、估算收益、更新时间。")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("基金助手")
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

private struct MarketIndexCard: View {
    let index: MarketIndexItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(index.name)
                .font(.headline)
            Text(DisplayFormatter.plain(index.latest, minimumFractionDigits: 2, maximumFractionDigits: 2))
                .font(.title3.weight(.semibold))
            Text("\(DisplayFormatter.signedPlain(index.change))  \(DisplayFormatter.percent(index.changePercent))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(index.changePercent.trendColor)
        }
        .frame(width: 168, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct PortfolioSummaryCard: View {
    let totalMarketValue: Double
    let totalPnL: Double
    let dailyPnL: Double
    let totalReturnPercent: Double?
    let updatedAt: Date?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("当前持有")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(DisplayFormatter.currency(totalMarketValue))
                        .font(.system(.title2, design: .rounded).weight(.bold))
                }

                Spacer()

                if let updatedAt {
                    Text("更新于 \(updatedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: columns, spacing: 12) {
                SummaryMetric(title: "今日收益", value: DisplayFormatter.signedCurrency(dailyPnL), tint: dailyPnL.trendColor)
                SummaryMetric(title: "持有收益", value: DisplayFormatter.signedCurrency(totalPnL), tint: totalPnL.trendColor)
                SummaryMetric(title: "收益率", value: totalReturnPercent.map(DisplayFormatter.percent) ?? "--", tint: (totalReturnPercent ?? 0).trendColor)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SummaryMetric: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(tint)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HoldingOverviewRow: View {
    let holding: StoredHolding
    let quote: RemoteFundSnapshot?
    let marketValue: Double?
    let totalPnL: Double?
    let dailyPnL: Double?
    let totalReturnPercent: Double?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(holding.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if holding.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    Text("\(holding.code) · 持有 \(DisplayFormatter.plain(holding.shares)) 份")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Text(DisplayFormatter.monthDayOrTime(quote?.displayTimestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                HoldingMetric(title: "估算净值", value: quote?.displayPrice.map(DisplayFormatter.price) ?? "--")
                HoldingMetric(title: "持有额", value: marketValue.map(DisplayFormatter.currency) ?? "--")
                HoldingMetric(title: "涨跌幅", value: quote?.displayChangePercent.map(DisplayFormatter.percent) ?? "--", tint: (quote?.displayChangePercent ?? 0).trendColor)
                HoldingMetric(title: "持有收益", value: totalPnL.map(DisplayFormatter.signedCurrency) ?? "--", tint: (totalPnL ?? 0).trendColor)
                HoldingMetric(title: "收益率", value: totalReturnPercent.map(DisplayFormatter.percent) ?? "--", tint: (totalReturnPercent ?? 0).trendColor)
                HoldingMetric(title: "估算收益", value: dailyPnL.map(DisplayFormatter.signedCurrency) ?? "--", tint: (dailyPnL ?? 0).trendColor)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct HoldingMetric: View {
    let title: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}