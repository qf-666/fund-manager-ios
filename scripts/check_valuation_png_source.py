from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def main() -> int:
    errors: list[str] = []

    detail_view = read("src/zhihu/FundDetailView.swift")

    tokens = [
        "AsyncImage(url: valuationChartImageURL(for: holding.code))",
        "https://j4.dfcfw.com/charts/pic6/",
        "东方财富实时 PNG 图源",
        "valuationChartImageURL(for code: String)",
        "supportsDirectValuationPNG",
    ]

    for token in tokens:
        if token not in detail_view:
            errors.append(f"FundDetailView.swift missing {token}")

    auto_load_snippet = """.task(id: holding.code) {
            await valuationChartLoader.load(code: holding.code)"""
    if auto_load_snippet in detail_view:
        errors.append("FundDetailView.swift should not auto-load valuation PNG on enter")

    if errors:
        print("Valuation PNG source check failed:")
        for item in errors:
            print(f"- {item}")
        return 1

    print("Valuation PNG source check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
