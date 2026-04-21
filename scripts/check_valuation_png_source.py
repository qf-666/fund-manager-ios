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

    required_detail_tokens = [
        "AsyncImage(url: valuationChartImageURL(for: holding.code))",
        "valuationChartImageURL(for code: String)",
        "FundValuationChartEndpoint.url(for: trimmedCode, cacheSeed: cacheSeed)",
        "valuationChartLoader.load(code: holding.code, force: true)",
        'Label("重新加载估值图", systemImage: "arrow.clockwise")',
    ]

    for token in required_detail_tokens:
        if token not in detail_view:
            errors.append(f"FundDetailView.swift missing {token}")

    required_auto_loads = [
        "if selectedTab == .valuation {\n                        valuationChartLoader.load(code: holding.code)",
        "if selectedTab == .valuation {\n                        valuationChartLoader.load(code: newCode)",
        "if newTab == .valuation {\n                        valuationChartLoader.load(code: holding.code)",
    ]
    for token in required_auto_loads:
        if token not in detail_view:
            errors.append("FundDetailView.swift should auto-load proxy valuation PNG")

    forbidden_manual_tokens = [
        "supportsDirectValuationPNG",
        "ProcessInfo.processInfo.operatingSystemVersion",
        'Label(valuationChartLoader.didFail ? "重新加载估值图" : "手动加载估值图"',
        "手动加载估值图",
        "iOS 16.3 及以下",
    ]
    for token in forbidden_manual_tokens:
        if token in detail_view:
            errors.append(f"FundDetailView.swift should not contain {token}")

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
