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
        'cardContainer(title: "净值估算图", subtitle: "直连 PNG（j4.dfcfw.com）")',
        'Text("图片源：直连 j4.dfcfw.com/charts/pic6/<基金代码>.png。")',
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
            errors.append("FundDetailView.swift should auto-load direct valuation PNG")

    forbidden_proxy_tokens = [
        "代理 PNG（缓存）",
        "图片源：代理缓存 PNG（上游为东方财富 pic6）。",
        "proxy valuation PNG",
        "bronze-fire.exe.xyz",
    ]
    for token in forbidden_proxy_tokens:
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
