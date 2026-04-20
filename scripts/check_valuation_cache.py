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
    api = read("src/core/EastMoneyAPI.swift")
    detail_view = read("src/zhihu/FundDetailView.swift")

    removed_tokens = {
        "src/core/Models.swift": [
            "struct FundValuationPoint",
            "struct FundValuationTrend",
            "struct CachedFundValuationTrend",
            "cachedValuationTrends",
        ],
        "src/core/AppViewModel.swift": [
            "loadValuationTrend(for code: String)",
            "cachedValuationTrend(for code: String)",
            "cacheValuationTrend(_ trend:",
            "cachedValuationTrends",
        ],
        "src/core/EastMoneyAPI.swift": [
            "fetchValuationTrend(code: String)",
            "FundVarietieValuationDetail.ashx",
        ],
        "src/zhihu/FundDetailView.swift": [
            "valuationTrend",
            "usingCachedValuationTrend",
            "valuationTrendSavedAt",
            "loadValuationTrend(for: code)",
            "cacheValuationTrend",
            "cachedValuationTrend(for: code)",
        ],
    }

    contents = {
        "src/core/Models.swift": models,
        "src/core/AppViewModel.swift": view_model,
        "src/core/EastMoneyAPI.swift": api,
        "src/zhihu/FundDetailView.swift": detail_view,
    }

    for file, tokens in removed_tokens.items():
        content = contents[file]
        for token in tokens:
            if token in content:
                errors.append(f"{file} should not contain {token}")

    required_detail_tokens = [
        "AsyncImage(url: valuationChartImageURL(for: holding.code))",
        "https://j4.dfcfw.com/charts/pic6/",
    ]
    for token in required_detail_tokens:
        if token not in detail_view:
            errors.append(f"FundDetailView.swift missing {token}")

    if errors:
        print("Valuation legacy removal check failed:")
        for item in errors:
            print(f"- {item}")
        return 1

    print("Valuation legacy removal check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
