from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def main() -> int:
    errors: list[str] = []

    models = read("src/core/Models.swift")
    view_model = read("src/core/AppViewModel.swift")
    detail_view = read("src/zhihu/FundDetailView.swift")

    model_tokens = [
        "struct CachedFundValuationTrend",
        "var cachedValuationTrends",
        "case cachedValuationTrends",
    ]
    for token in model_tokens:
        if token not in models:
            errors.append(f"Models.swift missing {token}")

    view_model_tokens = [
        "func cachedValuationTrend(for code: String)",
        "func cacheValuationTrend(_ trend: FundValuationTrend, for code: String)",
        "state.cachedValuationTrends[code]",
    ]
    for token in view_model_tokens:
        if token not in view_model:
            errors.append(f"AppViewModel.swift missing {token}")

    detail_tokens = [
        "if let freshTrend = await viewModel.loadValuationTrend",
        "viewModel.cacheValuationTrend",
        "viewModel.cachedValuationTrend(for: code)",
        "估值曲线暂时未更新，已展示上次成功缓存",
    ]
    for token in detail_tokens:
        if token not in detail_view:
            errors.append(f"FundDetailView.swift missing {token}")

    if errors:
        print("Valuation cache check failed:")
        for item in errors:
            print(f"- {item}")
        return 1

    print("Valuation cache check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
