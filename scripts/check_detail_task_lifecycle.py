from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DETAIL_VIEW = ROOT / "src" / "zhihu" / "FundDetailView.swift"
DETAIL_LOADER = ROOT / "src" / "zhihu" / "FundDetailLoader.swift"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def main() -> int:
    detail_view = read(DETAIL_VIEW)
    detail_loader = read(DETAIL_LOADER)
    errors: list[str] = []

    required_detail_tokens = [
        '@StateObject private var detailLoader = FundDetailLoader()',
        'detailLoader.load(code: holding.code, range: selectedRange, viewModel: viewModel)',
        'detailLoader.cancelAll()',
        'detailLoader.reloadSeries(code: holding.code, range: selectedRange, viewModel: viewModel)',
        'viewModel.resumeAutoRefresh(refreshNow: false)',
    ]
    for token in required_detail_tokens:
        if token not in detail_view:
            errors.append(f'FundDetailView.swift missing {token}')

    forbidden_detail_tokens = [
        '.task(id: holding.code)',
        'Task { await loadSeries(for: holding.code) }',
        'resumeAutoRefresh(refreshNow: true)',
        'private func loadInitialData(for code: String) async',
        'private func loadSeries(for code: String) async',
    ]
    for token in forbidden_detail_tokens:
        if token in detail_view:
            errors.append(f'FundDetailView.swift should not contain {token}')

    required_loader_tokens = [
        'final class FundDetailLoader: ObservableObject',
        'private var overviewTask: Task<Void, Never>?',
        'private var seriesTask: Task<Void, Never>?',
        'private var overviewGeneration = 0',
        'private var seriesGeneration = 0',
        'func cancelAll()',
        'overviewTask = Task { [weak self] in',
        'seriesTask = Task { [weak self] in',
    ]
    for token in required_loader_tokens:
        if token not in detail_loader:
            errors.append(f'FundDetailLoader.swift missing {token}')

    if errors:
        print('Detail task lifecycle check failed:')
        for item in errors:
            print(f'- {item}')
        return 1

    print('Detail task lifecycle check passed.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
