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
            "AsyncImage(url: valuationChartImageURL(for: holding.code))",
            "valuationChartImageURL(for code: String)",
            "https://j4.dfcfw.com/charts/pic6/",
        ],
    }

    sources = {
        "FundDetailView.swift": detail_view,
    }

    for file_name, tokens in required_checks.items():
        content = sources[file_name]
        for token in tokens:
            if token not in content:
                errors.append(f"{file_name} missing {token}")

    forbidden_tokens = [
        "Chart(valuationTrend.points)",
        "func loadValuationTrend(for code: String) async -> FundValuationTrend?",
        "func fetchValuationTrend(code: String) async throws -> FundValuationTrend?",
        "FundVarietieValuationDetail.ashx",
    ]

    for token in forbidden_tokens:
        if token in detail_view or token in api or token in view_model:
            errors.append(f"project should not contain {token}")

    if errors:
        print("Valuation chart source check failed:")
        for item in errors:
            print(f"- {item}")
        return 1

    print("Valuation chart source check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
