import Foundation
import SwiftUI

struct StoredHolding: Identifiable, Codable, Hashable {
    var id: UUID
    var code: String
    var name: String
    var shares: Double
    var costPerUnit: Double
    var notes: String
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        code: String,
        name: String,
        shares: Double = 0,
        costPerUnit: Double = 0,
        notes: String = "",
        isPinned: Bool = false
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.shares = shares
        self.costPerUnit = costPerUnit
        self.notes = notes
        self.isPinned = isPinned
    }

    var totalCost: Double {
        max(0, shares) * max(0, costPerUnit)
    }

    var hasPosition: Bool {
        shares > 0.0001
    }
}

struct MarketIndexItem: Identifiable, Hashable {
    var id: String { code }
    let code: String
    let name: String
    let latest: Double
    let change: Double
    let changePercent: Double
}

struct FundSearchItem: Identifiable, Hashable {
    var id: String { code }
    let code: String
    let name: String
    let pinyin: String
    let category: String
}

struct RemoteFundSnapshot: Identifiable, Hashable {
    var id: String { code }
    let code: String
    let name: String
    let nav: Double?
    let estimatedNav: Double?
    let estimatedChangePercent: Double?
    let dailyNavChangePercent: Double?
    let reportDate: String?
    let estimatedTime: String?

    private var reportDay: String? {
        reportDate.map { String($0.prefix(10)) }
    }

    private var estimatedDay: String? {
        estimatedTime.map { String($0.prefix(10)) }
    }

    var prefersOfficialSnapshot: Bool {
        if let reportDay, let estimatedDay {
            return reportDay == estimatedDay
        }
        return estimatedNav == nil && estimatedChangePercent == nil
    }

    var displayPrice: Double? {
        if prefersOfficialSnapshot {
            return nav ?? estimatedNav
        }
        return estimatedNav ?? nav
    }

    var displayChangePercent: Double? {
        if prefersOfficialSnapshot {
            return dailyNavChangePercent ?? estimatedChangePercent
        }
        return estimatedChangePercent ?? dailyNavChangePercent
    }

    var marketValuePrice: Double? {
        nav ?? displayPrice
    }

    var dailyPnLPerUnit: Double? {
        if prefersOfficialSnapshot, let nav, let changePercent = dailyNavChangePercent {
            let ratio = 1 + changePercent / 100
            guard abs(ratio) > .ulpOfOne else { return nil }
            return nav - nav / ratio
        }

        guard let estimatedNav, let nav else { return nil }
        return estimatedNav - nav
    }

    var displayTimestamp: String? {
        prefersOfficialSnapshot ? (reportDate ?? estimatedTime) : (estimatedTime ?? reportDate)
    }

    func merged(with estimate: FundEstimateSnapshot?) -> RemoteFundSnapshot {
        guard let estimate, estimate.code == code else { return self }
        return RemoteFundSnapshot(
            code: code,
            name: name,
            nav: nav ?? estimate.nav,
            estimatedNav: estimatedNav ?? estimate.estimatedNav,
            estimatedChangePercent: estimatedChangePercent ?? estimate.estimatedChangePercent,
            dailyNavChangePercent: dailyNavChangePercent,
            reportDate: reportDate ?? estimate.reportDate,
            estimatedTime: estimatedTime ?? estimate.estimatedTime
        )
    }
}

struct FundEstimateSnapshot: Hashable {
    let code: String
    let nav: Double?
    let estimatedNav: Double?
    let estimatedChangePercent: Double?
    let reportDate: String?
    let estimatedTime: String?
}

struct FundProfile: Hashable {
    let code: String
    let name: String
    let company: String
    let manager: String
    let fundType: String
    let riskLevel: String
    let subscriptionStatus: String
    let redemptionStatus: String
    let unitNAV: Double?
    let unitNAVDate: String?
    let accumulatedNAV: Double?
    let scale: Double?
    let oneMonthReturn: Double?
    let oneMonthRank: String?
    let threeMonthReturn: Double?
    let threeMonthRank: String?
    let sixMonthReturn: Double?
    let sixMonthRank: String?
    let oneYearReturn: Double?
    let oneYearRank: String?
}

struct NAVPoint: Identifiable, Hashable {
    let date: Date
    let unitValue: Double
    let accumulatedValue: Double?
    let dailyChangePercent: Double?

    var id: TimeInterval {
        date.timeIntervalSince1970
    }
}

struct FundPositionHolding: Identifiable, Hashable {
    let code: String
    let name: String
    let latestPrice: Double?
    let changePercent: Double?
    let positionRatio: Double?
    let changeFromPrevious: Double?
    let changeFromPreviousType: String?

    var id: String { code }

    var previousPeriodText: String {
        guard changeFromPreviousType != "新增" else { return "新增" }
        guard let changeFromPrevious else { return "--" }
        let arrow = changeFromPrevious >= 0 ? "↑" : "↓"
        return "\(arrow) \(String(format: "%.2f%%", abs(changeFromPrevious)))"
    }
}

struct FundPositionSnapshot: Hashable {
    let asOfDate: String?
    let holdings: [FundPositionHolding]
}

struct FundYieldPoint: Identifiable, Hashable {
    let date: Date
    let fundYield: Double
    let benchmarkYield: Double?
    let peerAverageYield: Double?

    var id: TimeInterval {
        date.timeIntervalSince1970
    }
}

struct PortfolioSummary {
    let totalCost: Double
    let totalMarketValue: Double
    let totalPnL: Double
    let dailyPnL: Double

    var totalReturnPercent: Double? {
        guard totalCost > 0 else { return nil }
        return totalPnL / totalCost * 100
    }
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppIconOption: String, Codable, CaseIterable, Identifiable {
    case ice
    case deep
    case emerald

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ice: return "冰川"
        case .deep: return "深海"
        case .emerald: return "翡翠"
        }
    }

    var subtitle: String {
        switch self {
        case .ice: return "原生感最强，冷静耐看"
        case .deep: return "更像高端资产管理"
        case .emerald: return "增长感更明显，辨识度更高"
        }
    }

    var previewAssetName: String {
        switch self {
        case .ice: return "IconPreviewIce"
        case .deep: return "IconPreviewDeep"
        case .emerald: return "IconPreviewEmerald"
        }
    }

    var alternateIconName: String? {
        switch self {
        case .ice: return nil
        case .deep: return "AppIconDeep"
        case .emerald: return "AppIconEmerald"
        }
    }

    var tint: Color {
        switch self {
        case .ice: return Color(red: 0.30, green: 0.54, blue: 0.92)
        case .deep: return Color(red: 0.19, green: 0.30, blue: 0.71)
        case .emerald: return Color(red: 0.20, green: 0.69, blue: 0.62)
        }
    }
}

enum ChartRange: String, CaseIterable, Identifiable {
    case month = "y"
    case quarter = "3y"
    case halfYear = "6y"
    case year = "n"
    case threeYears = "3n"
    case fiveYears = "5n"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: return "月"
        case .quarter: return "季"
        case .halfYear: return "半年"
        case .year: return "一年"
        case .threeYears: return "三年"
        case .fiveYears: return "五年"
        }
    }
}

struct AppState: Codable {
    var deviceId: String
    var holdings: [StoredHolding]
    var theme: AppTheme
    var appIcon: AppIconOption
    var autoRefreshIntervalSeconds: Int

    enum CodingKeys: String, CodingKey {
        case deviceId
        case holdings
        case theme
        case appIcon
        case autoRefreshIntervalSeconds
    }

    init(
        deviceId: String,
        holdings: [StoredHolding],
        theme: AppTheme,
        appIcon: AppIconOption = .ice,
        autoRefreshIntervalSeconds: Int = 10
    ) {
        self.deviceId = deviceId
        self.holdings = holdings
        self.theme = theme
        self.appIcon = appIcon
        self.autoRefreshIntervalSeconds = autoRefreshIntervalSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        holdings = try container.decode([StoredHolding].self, forKey: .holdings)
        theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
        appIcon = try container.decodeIfPresent(AppIconOption.self, forKey: .appIcon) ?? .ice
        autoRefreshIntervalSeconds = try container.decodeIfPresent(Int.self, forKey: .autoRefreshIntervalSeconds) ?? 10
    }

    static func seeded(deviceId: String = UUID().uuidString) -> AppState {
        AppState(
            deviceId: deviceId,
            holdings: [
                StoredHolding(code: "110011", name: "易方达优质精选混合（QDII）", shares: 120, costPerUnit: 4.61, notes: "默认示例组合", isPinned: true),
                StoredHolding(code: "001632", name: "天弘中证食品饮料 ETF 联接 C", shares: 200, costPerUnit: 1.95),
                StoredHolding(code: "161725", name: "招商中证白酒指数（LOF）A", shares: 80, costPerUnit: 0.68)
            ],
            theme: .system,
            appIcon: .ice,
            autoRefreshIntervalSeconds: 10
        )
    }
}

enum DisplayFormatter {
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    private static let compactCurrencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    private static let inputFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static func currency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "¥0.00"
    }

    static func compactCurrency(_ value: Double) -> String {
        compactCurrencyFormatter.string(from: NSNumber(value: value)) ?? currency(value)
    }

    static func signedCurrency(_ value: Double) -> String {
        if value > 0 {
            return "+" + currency(abs(value))
        }
        if value < 0 {
            return "-" + currency(abs(value))
        }
        return currency(0)
    }

    static func price(_ value: Double) -> String {
        priceFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.4f", value)
    }

    static func plain(_ value: Double, minimumFractionDigits: Int = 2, maximumFractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func signedPlain(_ value: Double, minimumFractionDigits: Int = 2, maximumFractionDigits: Int = 2) -> String {
        let absolute = plain(abs(value), minimumFractionDigits: minimumFractionDigits, maximumFractionDigits: maximumFractionDigits)
        if value > 0 { return "+\(absolute)" }
        if value < 0 { return "-\(absolute)" }
        return absolute
    }
    static func percent(_ value: Double) -> String {
        String(format: "%+.2f%%", value)
    }

    static func decimalInput(_ value: Double) -> String {
        guard value != 0 else { return "" }
        return inputFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func date(_ rawValue: String?) -> Date? {
        guard let rawValue, !rawValue.isEmpty else { return nil }
        let formats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "MM-dd"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: rawValue) {
                return date
            }
        }
        return nil
    }

    static func dayLabel(_ rawValue: String?) -> String {
        guard let date = date(rawValue) else { return rawValue ?? "--" }
        return date.formatted(.dateTime.month(.twoDigits).day(.twoDigits))
    }

    static func quoteTimestamp(_ rawValue: String?, preferTime: Bool) -> String {
        guard let date = date(rawValue) else { return rawValue ?? "--" }
        if preferTime, rawValue?.contains(":") == true {
            return date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        }
        return date.formatted(.dateTime.month(.twoDigits).day(.twoDigits))
    }

    static func monthDayOrTime(_ rawValue: String?) -> String {
        guard let rawValue else { return "--" }
        if rawValue.contains(":") {
            return quoteTimestamp(rawValue, preferTime: true)
        }
        return dayLabel(rawValue)
    }
}

extension Double {
    var trendColor: Color {
        self >= 0 ? .red : .green
    }
}
