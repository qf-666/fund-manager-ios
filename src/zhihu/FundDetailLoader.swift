import Foundation

@MainActor
final class FundDetailLoader: ObservableObject {
    @Published private(set) var profile: FundProfile?
    @Published private(set) var positionSnapshot: FundPositionSnapshot?
    @Published private(set) var series: [NAVPoint] = []
    @Published private(set) var isLoadingOverview = false
    @Published private(set) var isLoadingSeries = false

    private var activeCode: String?
    private var overviewTask: Task<Void, Never>?
    private var seriesTask: Task<Void, Never>?
    private var overviewGeneration = 0
    private var seriesGeneration = 0

    func load(code: String, range: ChartRange, viewModel: AppViewModel) {
        let normalizedCode = normalized(code)
        guard !normalizedCode.isEmpty else {
            reset()
            return
        }

        if activeCode != normalizedCode {
            profile = nil
            positionSnapshot = nil
            series = []
        }

        activeCode = normalizedCode
        loadOverview(code: normalizedCode, viewModel: viewModel)
        loadSeries(code: normalizedCode, range: range, viewModel: viewModel)
    }

    func reloadSeries(code: String, range: ChartRange, viewModel: AppViewModel) {
        let normalizedCode = normalized(code)
        guard !normalizedCode.isEmpty else {
            reset()
            return
        }

        activeCode = normalizedCode
        loadSeries(code: normalizedCode, range: range, viewModel: viewModel)
    }

    func cancelAll() {
        overviewTask?.cancel()
        seriesTask?.cancel()
        overviewTask = nil
        seriesTask = nil
        isLoadingOverview = false
        isLoadingSeries = false
    }

    func reset() {
        cancelAll()
        activeCode = nil
        profile = nil
        positionSnapshot = nil
        series = []
    }

    private func loadOverview(code: String, viewModel: AppViewModel) {
        overviewTask?.cancel()
        overviewGeneration += 1
        let generation = overviewGeneration
        isLoadingOverview = true

        overviewTask = Task { [weak self] in
            guard let self else { return }

            defer {
                if self.overviewGeneration == generation, self.activeCode == code {
                    self.isLoadingOverview = false
                    self.overviewTask = nil
                }
            }

            let profile = await viewModel.loadProfile(for: code)
            guard !Task.isCancelled, self.overviewGeneration == generation, self.activeCode == code else { return }
            self.profile = profile

            let positionSnapshot = await viewModel.loadPositionSnapshot(for: code)
            guard !Task.isCancelled, self.overviewGeneration == generation, self.activeCode == code else { return }
            self.positionSnapshot = positionSnapshot
        }
    }

    private func loadSeries(code: String, range: ChartRange, viewModel: AppViewModel) {
        seriesTask?.cancel()
        seriesGeneration += 1
        let generation = seriesGeneration
        isLoadingSeries = true

        seriesTask = Task { [weak self] in
            guard let self else { return }

            defer {
                if self.seriesGeneration == generation, self.activeCode == code {
                    self.isLoadingSeries = false
                    self.seriesTask = nil
                }
            }

            let series = await viewModel.loadNetValueSeries(for: code, range: range)
            guard !Task.isCancelled, self.seriesGeneration == generation, self.activeCode == code else { return }
            self.series = series
        }
    }

    private func normalized(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
