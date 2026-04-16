import SwiftUI
import Charts

struct FundDetailView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    let holdingID: UUID

    @State private var selectedRange: ChartRange = .year
    @State private var series: [NAVPoint] = []
    @State private var profile: FundProfile?
    @State private var isLoading = false
    @State private var editingHolding: StoredHolding?

    private var holding: StoredHolding? {
        viewModel.holding(id: holdingID)
    }

    private var quote: RemoteFundSnapshot? {
        guard let holding else { return nil }
        return viewModel.quote(for: holding.code)
    }

    var body: some View {
        Group {
            if let holding {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headerCard(for: holding)
                        chartCard
                        profileCard
                    }
                    .padding(16)
                }
                .navigationTitle(holding.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("编辑") {
                            editingHolding = holding
                        }
                    }
                }
                .task(id: selectedRange) {
                    await loadData(for: holding.code)
                }
                .sheet(item: $editingHolding) { draft in
                    EditHoldingSheet(holding: draft) { updated in
                        viewModel.saveHolding(updated)
                    }
                }
            } else {
                ContentUnavailableView("基金不存在", systemImage: "exclamationmark.triangle")
            }
        }
    }

    @ViewBuilder
    private func headerCard(for holding: StoredHolding) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(holding.code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(quote?.name ?? holding.name)
                        .font(.title3.weight(.semibold))
                }
                Spacer()
                if let updatedAt = quote?.estimatedTime ?? quote?.reportDate {
                    Text(DisplayFormatter.dayLabel(updatedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(quote?.displayPrice.map(DisplayFormatter.price) ?? "--")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                if let changePercent = quote?.displayChangePercent {
                    Text(DisplayFormatter.percent(changePercent))
                        .font(.headline)
                        .foregroundStyle(changePercent.trendColor)
                }
            }

            let totalCost = holding.totalCost
            let marketValue = viewModel.marketValue(for: holding)
            let totalPnL = viewModel.totalPnL(for: holding)
            let dailyPnL = viewModel.dailyPnL(for: holding)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statPill(title: "持仓份额", value: DisplayFormatter.price(holding.shares))
                statPill(title: "成本价", value: DisplayFormatter.price(holding.costPerUnit))
                statPill(title: "总成本", value: DisplayFormatter.currency(totalCost))
                statPill(title: "当前市值", value: marketValue.map(DisplayFormatter.currency) ?? "--")
                statPill(title: "累计浮盈", value: totalPnL.map(DisplayFormatter.signedCurrency) ?? "--", tint: (totalPnL ?? 0).trendColor)
                statPill(title: "今日变化", value: dailyPnL.map(DisplayFormatter.signedCurrency) ?? "--", tint: (dailyPnL ?? 0).trendColor)
            }

            if !holding.notes.isEmpty {
                Text(holding.notes)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("净值曲线")
                    .font(.headline)
                Spacer()
                Picker("区间", selection: $selectedRange) {
                    ForEach(ChartRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
            }

            if isLoading {
                ProgressView("加载曲线中…")
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else if series.isEmpty {
                ContentUnavailableView(
                    "暂无净值数据",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("可以稍后刷新，或尝试切换其他基金。")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                Chart(series) { point in
                    LineMark(
                        x: .value("日期", point.date),
                        y: .value("净值", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue)

                    AreaMark(
                        x: .value("日期", point.date),
                        y: .value("净值", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue.opacity(0.12))
                }
                .frame(height: 240)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("基金信息")
                .font(.headline)

            if let profile {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    infoItem(title: "基金名称", value: profile.name)
                    infoItem(title: "基金代码", value: profile.code)
                    infoItem(title: "基金类型", value: profile.fundType)
                    infoItem(title: "风险等级", value: profile.riskLevel)
                    infoItem(title: "基金公司", value: profile.company)
                    infoItem(title: "基金经理", value: profile.manager)
                    infoItem(title: "申购状态", value: profile.subscriptionStatus)
                    infoItem(title: "赎回状态", value: profile.redemptionStatus)
                }
            } else {
                ProgressView("加载详情中…")
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func loadData(for code: String) async {
        isLoading = true
        async let points = viewModel.loadNetValueSeries(for: code, range: selectedRange)
        async let profileTask = viewModel.loadProfile(for: code)
        series = await points
        profile = await profileTask
        isLoading = false
    }

    private func statPill(title: String, value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func infoItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
