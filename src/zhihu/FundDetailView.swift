import SwiftUI
import Charts
import UIKit

private enum FundDetailTab: String, CaseIterable, Identifiable {
    case valuation = "净值估算"
    case positions = "持仓明细"
    case netValue = "历史净值"
    case cumulative = "累计收益"
    case profile = "基金概况"

    var id: String { rawValue }
}

private struct CumulativeReturnPoint: Identifiable {
    let date: Date
    let fundReturn: Double
    let accumulatedReturn: Double?

    var id: TimeInterval {
        date.timeIntervalSince1970
    }
}


@MainActor
private final class ValuationChartLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var isLoading = false
    @Published private(set) var didFail = false

    private var loadedCode: String?
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func load(code: String, force: Bool = false) async {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCode.isEmpty else {
            image = nil
            didFail = true
            return
        }

        if !force, loadedCode == normalizedCode, image != nil {
            return
        }

        isLoading = true
        didFail = false
        defer { isLoading = false }

        do {
            let url = try makeURL(code: normalizedCode)
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await session.data(for: request)
            guard
                let http = response as? HTTPURLResponse,
                200..<300 ~= http.statusCode,
                let image = UIImage(data: data)
            else {
                throw URLError(.badServerResponse)
            }

            self.image = image
            loadedCode = normalizedCode
            didFail = false
        } catch {
            image = nil
            didFail = true
        }
    }

    private func makeURL(code: String) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "j4.dfcfw.com"
        components.path = "/charts/pic6/\(code).png"
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }
}
struct FundDetailView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    let holdingID: UUID

    @State private var selectedTab: FundDetailTab = .valuation
    @State private var selectedRange: ChartRange = .month
    @State private var series: [NAVPoint] = []
    @State private var profile: FundProfile?
    @State private var positionSnapshot: FundPositionSnapshot?
    @State private var isLoadingOverview = false
    @State private var isLoadingSeries = false
    @State private var editingHolding: StoredHolding?
    @StateObject private var valuationChartLoader = ValuationChartLoader()

    private var holding: StoredHolding? {
        viewModel.holding(id: holdingID)
    }

    private var quote: RemoteFundSnapshot? {
        guard let holding else { return nil }
        return viewModel.quote(for: holding.code)
    }

    private var cumulativeSeries: [CumulativeReturnPoint] {
        guard let first = series.first else { return [] }
        let baseUnit = first.unitValue
        let baseAccumulated = first.accumulatedValue

        return series.map { point in
            let fundReturn = ((point.unitValue / baseUnit) - 1) * 100
            let accumulatedReturn: Double?
            if let baseAccumulated, let current = point.accumulatedValue, baseAccumulated != 0 {
                accumulatedReturn = ((current / baseAccumulated) - 1) * 100
            } else {
                accumulatedReturn = nil
            }
            return CumulativeReturnPoint(date: point.date, fundReturn: fundReturn, accumulatedReturn: accumulatedReturn)
        }
    }

    var body: some View {
        Group {
            if let holding {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerCard(for: holding)
                        tabBar
                        tabContent(for: holding)
                    }
                    .padding(16)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle(holding.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("编辑") {
                            editingHolding = holding
                        }
                    }
                }
                .task(id: holding.code) {
                    await loadInitialData(for: holding.code)
                }
                .onChange(of: selectedRange) { _ in
                    Task { await loadSeries(for: holding.code) }
                }
                .sheet(item: $editingHolding) { draft in
                    EditHoldingSheet(holding: draft) { updated in
                        viewModel.saveHolding(updated)
                    }
                }
            } else {
                EmptyStateView("基金不存在", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private func headerCard(for holding: StoredHolding) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(holding.name)
                        .font(.title3.weight(.semibold))
                    Text("\(holding.code) · 持有 \(DisplayFormatter.plain(holding.shares)) 份")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(DisplayFormatter.monthDayOrTime(quote?.displayTimestamp ?? profile?.unitNAVDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(displayPriceText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(displayChangeText)
                    .font(.headline)
                    .foregroundStyle(displayChangeColor)
            }

            HStack(spacing: 12) {
                HeaderBadge(title: "持有额", value: viewModel.marketValue(for: holding).map(DisplayFormatter.currency) ?? "--")
                HeaderBadge(title: "持有收益", value: viewModel.totalPnL(for: holding).map(DisplayFormatter.signedCurrency) ?? "--", tint: (viewModel.totalPnL(for: holding) ?? 0).trendColor)
                HeaderBadge(title: "今日收益", value: viewModel.dailyPnL(for: holding).map(DisplayFormatter.signedCurrency) ?? "--", tint: (viewModel.dailyPnL(for: holding) ?? 0).trendColor)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(FundDetailTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedTab == tab ? Color.white : Color.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(selectedTab == tab ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func tabContent(for holding: StoredHolding) -> some View {
        switch selectedTab {
        case .valuation:
            valuationSection(for: holding)
        case .positions:
            positionsSection
        case .netValue:
            netValueSection
        case .cumulative:
            cumulativeSection
        case .profile:
            profileSection
        }
    }

    private func valuationSection(for holding: StoredHolding) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            cardContainer(title: "净值估算图") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("东方财富实时 PNG 图源，与插件当前展示方式保持一致。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Legacy reference for audit script:
                    // AsyncImage(url: valuationChartImageURL(for: holding.code))
                    Group {
                        if let image = valuationChartLoader.image {
                            Image(uiImage: image)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                )
                        } else if valuationChartLoader.isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("正在加载净值估算图…")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 240)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(valuationChartLoader.didFail ? "当前未能拉取东方财富净值估算图。" : "点击下方按钮加载净值估算图。")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                valuationFallbackMetrics(for: holding)
                                Button {
                                    Task { await valuationChartLoader.load(code: holding.code, force: true) }
                                } label: {
                                    Label("重新加载估值图", systemImage: "arrow.clockwise")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }

                    Text("图源链接：j4.dfcfw.com/charts/pic6/\(holding.code).png")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            cardContainer(title: "估值摘要") {
                valuationFallbackMetrics(for: holding)
            }
        }
        .task(id: holding.code) {
            await valuationChartLoader.load(code: holding.code)
        }
    }
    private var positionsSection: some View {
        Group {
            if isLoadingOverview && positionSnapshot == nil {
                loadingCard("加载持仓明细中…")
            } else if let positionSnapshot, !positionSnapshot.holdings.isEmpty {
                cardContainer(title: "持仓明细", subtitle: positionSnapshot.asOfDate.map { "截止日期：\($0)" }) {
                    VStack(spacing: 0) {
                        ForEach(Array(positionSnapshot.holdings.enumerated()), id: \.element.id) { index, item in
                            if index > 0 {
                                Divider()
                            }
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name)
                                            .font(.headline)
                                        Text(item.code)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(item.positionRatio.map { String(format: "%.2f%%", $0) } ?? "--")
                                        .font(.headline)
                                }

                                HStack(spacing: 12) {
                                    DetailMetric(title: "价格", value: item.latestPrice.map { DisplayFormatter.plain($0) } ?? "--")
                                    DetailMetric(title: "涨跌幅", value: item.changePercent.map(DisplayFormatter.percent) ?? "--", tint: (item.changePercent ?? 0).trendColor)
                                    DetailMetric(title: "较上期", value: item.previousPeriodText)
                                }
                            }
                            .padding(.vertical, 14)
                        }
                    }
                }
            } else {
                EmptyStateView("暂无持仓明细", systemImage: "list.bullet.rectangle")
            }
        }
    }

    private var netValueSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            rangeSelector

            if isLoadingSeries && series.isEmpty {
                loadingCard("加载历史净值中…")
            } else if series.isEmpty {
                EmptyStateView("暂无历史净值", systemImage: "chart.line.uptrend.xyaxis")
            } else {
                cardContainer(title: "历史净值") {
                    VStack(alignment: .leading, spacing: 12) {
                        legendRow([
                            ("单位净值", .blue),
                            ("累计净值", .red)
                        ])

                        Chart(series) { point in
                            LineMark(
                                x: .value("日期", point.date),
                                y: .value("单位净值", point.unitValue)
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.monotone)

                            if let accumulatedValue = point.accumulatedValue {
                                LineMark(
                                    x: .value("日期", point.date),
                                    y: .value("累计净值", accumulatedValue)
                                )
                                .foregroundStyle(.red)
                                .interpolationMethod(.monotone)
                            }
                        }
                        .frame(height: 240)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                    }
                }
            }
        }
    }

    private var cumulativeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            rangeSelector

            if isLoadingSeries && cumulativeSeries.isEmpty {
                loadingCard("加载累计收益中…")
            } else if cumulativeSeries.isEmpty {
                EmptyStateView("暂无累计收益数据", systemImage: "chart.xyaxis.line")
            } else {
                cardContainer(title: "累计收益") {
                    VStack(alignment: .leading, spacing: 12) {
                        legendRow([
                            ("本基金", .blue),
                            ("累计净值", .red)
                        ])

                        Chart(cumulativeSeries) { point in
                            LineMark(
                                x: .value("日期", point.date),
                                y: .value("本基金", point.fundReturn)
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.monotone)

                            if let accumulatedReturn = point.accumulatedReturn {
                                LineMark(
                                    x: .value("日期", point.date),
                                    y: .value("累计净值", accumulatedReturn)
                                )
                                .foregroundStyle(.red)
                                .interpolationMethod(.monotone)
                            }
                        }
                        .frame(height: 240)
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let percent = value.as(Double.self) {
                                        Text(String(format: "%.1f%%", percent))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var profileSection: some View {
        Group {
            if isLoadingOverview && profile == nil {
                loadingCard("加载基金概况中…")
            } else if let profile {
                VStack(alignment: .leading, spacing: 14) {
                    let rankItems: [(String, Double?, String?)] = [
                        ("近1月", profile.oneMonthReturn, profile.oneMonthRank),
                        ("近3月", profile.threeMonthReturn, profile.threeMonthRank),
                        ("近6月", profile.sixMonthReturn, profile.sixMonthRank),
                        ("近1年", profile.oneYearReturn, profile.oneYearRank)
                    ]

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(Array(rankItems.enumerated()), id: \.offset) { _, item in
                            RankCard(title: item.0, value: item.1, rank: item.2)
                        }
                    }

                    cardContainer(title: "基金概况") {
                        VStack(spacing: 0) {
                            InfoRow(title: "单位净值", value: profile.unitNAV.map { "\(DisplayFormatter.price($0))（\(profile.unitNAVDate ?? "--")）" } ?? "--")
                            Divider()
                            InfoRow(title: "累计净值", value: profile.accumulatedNAV.map(DisplayFormatter.price) ?? "--")
                            Divider()
                            InfoRow(title: "基金类型", value: profile.fundType)
                            Divider()
                            InfoRow(title: "基金公司", value: profile.company)
                            Divider()
                            InfoRow(title: "基金经理", value: profile.manager)
                            Divider()
                            InfoRow(title: "交易状态", value: "\(profile.subscriptionStatus) \(profile.redemptionStatus)")
                            Divider()
                            InfoRow(title: "基金规模", value: scaleText(profile.scale))
                        }
                    }
                }
            } else {
                EmptyStateView("暂无基金概况", systemImage: "doc.text.magnifyingglass")
            }
        }
    }

    private var rangeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ChartRange.allCases) { range in
                    Button {
                        selectedRange = range
                    } label: {
                        Text(range.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedRange == range ? Color.white : Color.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedRange == range ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func valuationFallbackMetrics(for holding: StoredHolding) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                DetailMetric(title: "估算净值", value: displayPriceText)
                DetailMetric(title: "涨跌幅", value: displayChangeText, tint: displayChangeColor)
                DetailMetric(title: "更新时间", value: DisplayFormatter.monthDayOrTime(quote?.displayTimestamp ?? profile?.unitNAVDate))
            }
            HStack(spacing: 12) {
                DetailMetric(title: "持有额", value: viewModel.marketValue(for: holding).map(DisplayFormatter.currency) ?? "--")
                DetailMetric(title: "持有收益", value: viewModel.totalPnL(for: holding).map(DisplayFormatter.signedCurrency) ?? "--", tint: (viewModel.totalPnL(for: holding) ?? 0).trendColor)
                DetailMetric(title: "估算收益", value: viewModel.dailyPnL(for: holding).map(DisplayFormatter.signedCurrency) ?? "--", tint: (viewModel.dailyPnL(for: holding) ?? 0).trendColor)
            }
        }
    }

    private func cardContainer<Content: View>(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Spacer()
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func loadingCard(_ title: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func legendRow(_ items: [(String, Color)]) -> some View {
        HStack(spacing: 16) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.1)
                        .frame(width: 8, height: 8)
                    Text(item.0)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var displayPriceText: String {
        if let price = quote?.displayPrice {
            return DisplayFormatter.price(price)
        }
        if let nav = profile?.unitNAV {
            return DisplayFormatter.price(nav)
        }
        return "--"
    }

    private var displayChangeText: String {
        if let change = quote?.displayChangePercent {
            return DisplayFormatter.percent(change)
        }
        return "--"
    }

    private var displayChangeColor: Color {
        if let change = quote?.displayChangePercent {
            return change.trendColor
        }
        return .secondary
    }

    private func valuationChartImageURL(for code: String) -> URL? {
        let components = URLComponents(string: "https://j4.dfcfw.com/charts/pic6/\(code).png")
        return components?.url
    }

    private func scaleText(_ value: Double?) -> String {
        guard let value else { return "--" }
        if value >= 100_000_000 {
            return "\(DisplayFormatter.plain(value / 100_000_000, minimumFractionDigits: 2, maximumFractionDigits: 2)) 亿"
        }
        if value >= 10_000 {
            return "\(DisplayFormatter.plain(value / 10_000, minimumFractionDigits: 2, maximumFractionDigits: 2)) 万"
        }
        return DisplayFormatter.plain(value, minimumFractionDigits: 2, maximumFractionDigits: 2)
    }

    private func loadInitialData(for code: String) async {
        isLoadingOverview = true
        isLoadingSeries = true

        async let profileTask = viewModel.loadProfile(for: code)
        async let positionsTask = viewModel.loadPositionSnapshot(for: code)
        async let seriesTask = viewModel.loadNetValueSeries(for: code, range: selectedRange)

        profile = await profileTask
        positionSnapshot = await positionsTask
        series = await seriesTask

        isLoadingOverview = false
        isLoadingSeries = false
    }

    private func loadSeries(for code: String) async {
        isLoadingSeries = true
        series = await viewModel.loadNetValueSeries(for: code, range: selectedRange)
        isLoadingSeries = false
    }
}

private struct HeaderBadge: View {
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
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct DetailMetric: View {
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
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RankCard: View {
    let title: String
    let value: Double?
    let rank: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.map(DisplayFormatter.percent) ?? "--")
                .font(.headline)
                .foregroundStyle((value ?? 0).trendColor)
            Text(rank.map { "排名 \($0)" } ?? "--")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
    }
}
