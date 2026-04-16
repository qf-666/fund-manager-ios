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

    var displayPrice: Double? {
        estimatedNav ?? nav
    }

    var displayChangePercent: Double? {
        estimatedChangePercent ?? dailyNavChangePercent
    }
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
}

struct NAVPoint: Identifiable, Hashable {
    let date: Date
    let value: Double

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

enum ChartRange: String, CaseIterable, Identifiable {
    case month = "y"
    case quarter = "3y"
    case year = "n"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: return "近 1 月"
        case .quarter: return "近 3 月"
        case .year: return "近 1 年"
        }
    }
}

struct AppState: Codable {
    var deviceId: String
    var holdings: [StoredHolding]
    var theme: AppTheme

    static func seeded(deviceId: String = UUID().uuidString) -> AppState {
        AppState(
            deviceId: deviceId,
            holdings: [
                StoredHolding(code: "110011", name: "易方达优质精选混合(QDII)", shares: 120, costPerUnit: 4.61, notes: "默认示例组合", isPinned: true),
                StoredHolding(code: "001632", name: "天弘中证食品饮料ETF联接C", shares: 200, costPerUnit: 1.95),
                StoredHolding(code: "161725", name: "招商中证白酒指数(LOF)A", shares: 80, costPerUnit: 0.68)
            ],
            theme: .system
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

    static func percent(_ value: Double) -> String {
        String(format: "%+.2f%%", value)
    }

    static func decimalInput(_ value: Double) -> String {
        guard value != 0 else { return "" }
        return inputFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func date(_ rawValue: String?) -> Date? {
        guard let rawValue, !rawValue.isEmpty else { return nil }
        let formats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"]
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
}

extension Double {
    var trendColor: Color {
        self >= 0 ? .red : .green
    }
}
