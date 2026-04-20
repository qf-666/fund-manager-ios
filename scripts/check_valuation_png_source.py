from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def main() -> int:
    errors: list[str] = []

    detail_view = read("src/zhihu/FundDetailView.swift")
    api = read("src/core/EastMoneyAPI.swift")
    view_model = read("src/core/AppViewModel.swift")

    required_checks = {
        "FundDetailView.swift": [
            "Chart(valuationTrend.points)",
        ],
        "EastMoneyAPI.swift": [
            "func fetchValuationTrend(code: String) async throws -> FundValuationTrend?",
            "FundVarietieValuationDetail.ashx",
        ],
        "AppViewModel.swift": [
            "func loadValuationTrend(for code: String) async -> FundValuationTrend?",
        ],
    }

    sources = {
        "FundDetailView.swift": detail_view,
        "EastMoneyAPI.swift": api,
        "AppViewModel.swift": view_model,
    }

    for file_name, tokens in required_checks.items():
        content = sources[file_name]
        for token in tokens:
            if token not in content:
                errors.append(f"{file_name} missing {token}")

    forbidden_tokens = [
        "AsyncImage(url: valuationChartImageURL(for: holding.code))",
        "https://bronze-fire.exe.xyz/fund-manager-ios/valuation-png/",
        "https://j4.dfcfw.com/charts/pic6/",
        "valuationChartImageURL(for code: String)",
    ]

    for token in forbidden_tokens:
        if token in detail_view:
            errors.append(f"FundDetailView.swift should not contain {token}")

    if errors:
        print("Valuation chart source check failed:")
        for item in errors:
            print(f"- {item}")
        return 1

    print("Valuation chart source check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
