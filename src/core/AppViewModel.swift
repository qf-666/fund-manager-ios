import Foundation
import UIKit

@MainActor
final class AppViewModel: ObservableObject {
    @Published var state: AppState
    @Published private(set) var quotes: [String: RemoteFundSnapshot] = [:]
    @Published private(set) var indices: [MarketIndexItem] = []
    @Published var searchResults: [FundSearchItem] = []
    @Published var isRefreshing = false
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var appIconErrorMessage: String?

    private let api: EastMoneyAPIProtocol
    private let store: PersistenceStore
    private var hasBootstrapped = false
    private var autoRefreshTask: Task<Void, Never>?
    private var autoRefreshAllowed = false

    init(api: EastMoneyAPIProtocol = EastMoneyAPI(), store: PersistenceStore = .shared) {
        self.api = api
        self.store = store
        self.state = store.load() ?? AppState.seeded()
    }

    var sortedHoldings: [StoredHolding] {
        state.holdings.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.code < $1.code
        }
    }

    var summary: PortfolioSummary {
        let positions = sortedHoldings.filter(\.hasPosition)
        let totalCost = positions.reduce(0) { $0 + $1.totalCost }
        let totalMarketValue = positions.reduce(0) { partialResult, holding in
            partialResult + (marketValue(for: holding) ?? 0)
        }
        let totalPnL = totalMarketValue - totalCost
        let dailyPnL = positions.reduce(0) { partialResult, holding in
            partialResult + (self.dailyPnL(for: holding) ?? 0)
        }
        return PortfolioSummary(
            totalCost: totalCost,
            totalMarketValue: totalMarketValue,
            totalPnL: totalPnL,
            dailyPnL: dailyPnL
        )
    }

    var storagePath: String {
        store.fileURL.path
    }

    var autoRefreshInterval: TimeInterval {
        guard state.autoRefreshIntervalSeconds > 0 else { return 0 }
        return TimeInterval(state.autoRefreshIntervalSeconds)
    }

    var autoRefreshDescription: String {
        let seconds = state.autoRefreshIntervalSeconds
        guard seconds > 0 else { return "已关闭" }
        if seconds % 60 == 0 {
            return "\(seconds / 60) 分钟"
        }
        return "\(seconds) 秒"
    }

    var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        await refreshAll(force: true)
    }

    func startAutoRefresh() {
        autoRefreshAllowed = true
        guard autoRefreshTask == nil, autoRefreshInterval > 0 else { return }

        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let interval = UInt64(self.autoRefreshInterval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: interval)
                guard !Task.isCancelled else { break }
                await self.refreshAll()
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshAllowed = false
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    func setAutoRefreshInterval(_ seconds: Int) {
        let clamped = max(0, min(seconds, 3600))
        state.autoRefreshIntervalSeconds = clamped
        persist()

        if autoRefreshAllowed {
            autoRefreshTask?.cancel()
            autoRefreshTask = nil
            startAutoRefresh()
        }
    }

    func refreshAll(force: Bool = false) async {
        guard !isRefreshing || force else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        var firstError: Error?
        var didUpdate = false

        do {
            let freshIndices = try await api.fetchIndices()
            indices = freshIndices
            didUpdate = true
        } catch {
            firstError = error
        }

        do {
            let freshSnapshots = try await fetchSnapshotsForCurrentHoldings()
            quotes = Dictionary(uniqueKeysWithValues: freshSnapshots.map { ($0.code, $0) })
            didUpdate = true
        } catch {
            if firstError == nil {
                firstError = error
            }
        }

        if didUpdate {
            lastUpdated = Date()
        }

        if let firstError {
            present(firstError)
        } else {
            errorMessage = nil
        }
    }

    func search(query: String) async {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            let results = try await api.searchFunds(matching: cleaned)
            let existingCodes = Set(state.holdings.map(\.code))
            searchResults = results
                .filter { !existingCodes.contains($0.code) }
                .prefix(30)
                .map { $0 }
        } catch {
            present(error)
        }
    }

    func addFund(_ item: FundSearchItem) {
        guard !state.holdings.contains(where: { $0.code == item.code }) else { return }
        state.holdings.append(StoredHolding(code: item.code, name: item.name))
        persist()
        searchResults.removeAll { $0.code == item.code }
        Task { await refreshAll(force: true) }
    }

    func saveHolding(_ holding: StoredHolding) {
        if let index = state.holdings.firstIndex(where: { $0.id == holding.id }) {
            state.holdings[index] = holding
        } else {
            state.holdings.append(holding)
        }
        persist()
        Task { await refreshAll(force: true) }
    }

    func deleteHolding(_ holding: StoredHolding) {
        state.holdings.removeAll { $0.id == holding.id }
        quotes.removeValue(forKey: holding.code)
        persist()
    }

    func togglePin(for holding: StoredHolding) {
        var updated = holding
        updated.isPinned.toggle()
        saveHolding(updated)
    }

    func setTheme(_ theme: AppTheme) {
        state.theme = theme
        persist()
    }

    func setAppIcon(_ icon: AppIconOption) async {
        let previousIcon = state.appIcon
        state.appIcon = icon
        persist()

        do {
            try await applyAppIcon(icon)
            appIconErrorMessage = nil
        } catch {
            state.appIcon = previousIcon
            persist()
            appIconErrorMessage = formatAppIconError(error, action: "切换图标")
        }
    }

    func syncAppIcon() async {
        guard supportsAlternateIcons else { return }
        guard UIApplication.shared.alternateIconName != state.appIcon.alternateIconName else { return }

        do {
            try await applyAppIcon(state.appIcon)
            appIconErrorMessage = nil
        } catch {
            appIconErrorMessage = formatAppIconError(error, action: "同步图标")
        }
    }

    func resetPortfolio() {
        let seeded = AppState.seeded(deviceId: state.deviceId)
        state = AppState(
            deviceId: seeded.deviceId,
            holdings: seeded.holdings,
            theme: state.theme,
            appIcon: state.appIcon,
            autoRefreshIntervalSeconds: state.autoRefreshIntervalSeconds
        )
        persist()
        Task { await refreshAll(force: true) }
    }

    func holding(id: UUID) -> StoredHolding? {
        state.holdings.first { $0.id == id }
    }

    func quote(for code: String) -> RemoteFundSnapshot? {
        quotes[code]
    }

    func marketValue(for holding: StoredHolding) -> Double? {
        guard holding.hasPosition, let price = quote(for: holding.code)?.marketValuePrice else {
            return nil
        }
        return price * holding.shares
    }

    func totalPnL(for holding: StoredHolding) -> Double? {
        guard holding.hasPosition else { return nil }
        guard let marketValue = marketValue(for: holding) else {
            return -holding.totalCost
        }
        return marketValue - holding.totalCost
    }

    func dailyPnL(for holding: StoredHolding) -> Double? {
        guard let dailyChangePerUnit = quote(for: holding.code)?.dailyPnLPerUnit else {
            return nil
        }
        return dailyChangePerUnit * holding.shares
    }

    func returnPercent(for holding: StoredHolding) -> Double? {
        guard let totalPnL = totalPnL(for: holding), holding.totalCost > 0 else {
            return nil
        }
        return totalPnL / holding.totalCost * 100
    }

    func loadProfile(for code: String) async -> FundProfile? {
        do {
            return try await api.fetchProfile(code: code)
        } catch {
            present(error)
            return nil
        }
    }

    func loadNetValueSeries(for code: String, range: ChartRange) async -> [NAVPoint] {
        do {
            return try await api.fetchNetValueSeries(code: code, range: range)
        } catch {
            present(error)
            return []
        }
    }

    func loadPositionSnapshot(for code: String) async -> FundPositionSnapshot? {
        do {
            return try await api.fetchPositionSnapshot(code: code)
        } catch {
            present(error)
            return nil
        }
    }

    private func fetchSnapshotsForCurrentHoldings() async throws -> [RemoteFundSnapshot] {
        let codes = state.holdings.map(\.code)
        guard !codes.isEmpty else { return [] }
        return try await api.fetchSnapshots(codes: codes, deviceId: state.deviceId)
    }

    private func persist() {
        store.save(state)
    }

    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    private func formatAppIconError(_ error: Error, action: String) -> String {
        let nsError = error as NSError
        let suffix = "\(nsError.domain) \(nsError.code)"

        if nsError.code == -54 {
            return "\(action)失败：\(nsError.localizedDescription)（\(suffix)）。当前无签名或侧载安装方式可能不支持动态切换桌面图标，可改装 Release 附带的固定图标版本。"
        }

        return "\(action)失败：\(nsError.localizedDescription)（\(suffix)）"
    }

    private func applyAppIcon(_ icon: AppIconOption) async throws {
        guard supportsAlternateIcons else { return }
        guard UIApplication.shared.alternateIconName != icon.alternateIconName else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UIApplication.shared.setAlternateIconName(icon.alternateIconName) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
