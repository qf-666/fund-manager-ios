import Foundation

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

    private let api: EastMoneyAPIProtocol
    private let store: PersistenceStore
    private var hasBootstrapped = false

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
            partialResult + (dailyPnL(for: holding) ?? 0)
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

    func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        await refreshAll(force: true)
    }

    func refreshAll(force: Bool = false) async {
        guard !isRefreshing || force else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            async let indicesTask = api.fetchIndices()
            async let snapshotsTask = fetchSnapshotsForCurrentHoldings()
            let freshIndices = try await indicesTask
            let freshSnapshots = try await snapshotsTask

            indices = freshIndices
            quotes = Dictionary(uniqueKeysWithValues: freshSnapshots.map { ($0.code, $0) })
            lastUpdated = Date()
            errorMessage = nil
        } catch {
            present(error)
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

    func resetPortfolio() {
        state = AppState.seeded(deviceId: state.deviceId)
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
        guard holding.hasPosition, let price = quote(for: holding.code)?.displayPrice else {
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
        guard let marketValue = marketValue(for: holding), let changePercent = quote(for: holding.code)?.displayChangePercent else {
            return nil
        }
        return marketValue * changePercent / 100
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
}
