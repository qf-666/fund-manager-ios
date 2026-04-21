from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DETAIL_VIEW = ROOT / "src" / "zhihu" / "FundDetailView.swift"
PNG_LOADER = ROOT / "src" / "zhihu" / "FundValuationChartLoader.swift"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def main() -> int:
    detail_view = read(DETAIL_VIEW)
    png_loader = read(PNG_LOADER)
    errors: list[str] = []

    required_detail_tokens = [
        '@StateObject private var valuationChartLoader = FundValuationChartLoader()',
        'valuationChartLoader.load(code: holding.code)',
        'valuationChartLoader.cancel()',
        'valuationChartLoader.reset()',
        'Image(uiImage: image)',
        'https://j4.dfcfw.com/charts/pic6/',
    ]
    for token in required_detail_tokens:
        if token not in detail_view:
            errors.append(f'FundDetailView.swift missing {token}')

    required_loader_tokens = [
        'final class FundValuationChartLoader: ObservableObject',
        '@Published private(set) var image: UIImage?',
        'private var loadTask: Task<Void, Never>?',
        'private var generation = 0',
        'func load(code: String, force: Bool = false)',
        'loadTask = Task { [weak self] in',
        'func cancel()',
        'func reset()',
        'configuration.urlCache = nil',
        'configuration.requestCachePolicy = .reloadIgnoringLocalCacheData',
        'components.host = "j4.dfcfw.com"',
        'components.path = "/charts/pic6/\\(code).png"',
    ]
    for token in required_loader_tokens:
        if token not in png_loader:
            errors.append(f'FundValuationChartLoader.swift missing {token}')

    if errors:
        print('Valuation PNG loader check failed:')
        for item in errors:
            print(f'- {item}')
        return 1

    print('Valuation PNG loader check passed.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
