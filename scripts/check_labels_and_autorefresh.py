from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def main() -> int:
    errors: list[str] = []

    app_view_model = read("src/core/AppViewModel.swift")
    models = read("src/core/Models.swift")
    app_entry = read("src/zhihu/ZhihuFundsApp.swift")
    home_view = read("src/zhihu/HomeView.swift")
    detail_view = read("src/zhihu/FundDetailView.swift")
    settings_view = read("src/zhihu/SettingsView.swift")

    required_view_model_tokens = [
        "var autoRefreshInterval:",
        "func startAutoRefresh()",
        "func stopAutoRefresh()",
        "func setAutoRefreshInterval(",
        "var autoRefreshDescription:",
    ]
    for token in required_view_model_tokens:
        if token not in app_view_model:
            errors.append(f"AppViewModel.swift missing {token}")

    if "autoRefreshIntervalSeconds" not in models:
        errors.append("Models.swift missing persisted autoRefreshIntervalSeconds")
    if "autoRefreshIntervalSeconds: 10" not in models:
        errors.append("Models.swift missing default auto refresh interval of 10 seconds")

    if "scenePhase" not in app_entry:
        errors.append("ZhihuFundsApp.swift missing scenePhase lifecycle handling")
    if ".onChange(of: scenePhase" not in app_entry:
        errors.append("ZhihuFundsApp.swift missing scenePhase change hook")

    expected_home = [
        "\u57fa\u91d1\u52a9\u624b",
        "\u5f53\u524d\u6301\u6709",
        "\u6211\u7684\u57fa\u91d1",
        "\u4f30\u7b97\u51c0\u503c",
        "\u6301\u6709\u989d",
        "\u6301\u6709\u6536\u76ca",
        "\u6536\u76ca\u7387",
        "\u6da8\u8dcc\u5e45",
        "\u4f30\u7b97\u6536\u76ca",
    ]
    for label in expected_home:
        if label not in home_view:
            errors.append(f"HomeView.swift missing label: {label}")

    expected_detail = [
        "enum FundDetailTab",
        "\u51c0\u503c\u4f30\u7b97",
        "\u6301\u4ed3\u660e\u7ec6",
        "\u5386\u53f2\u51c0\u503c",
        "\u7d2f\u8ba1\u6536\u76ca",
        "\u57fa\u91d1\u6982\u51b5",
        "\u51c0\u503c\u4f30\u7b97\u56fe",
        "\u4f30\u503c\u6458\u8981",
        "\u622a\u6b62\u65e5\u671f",
        "\u4ef7\u683c",
        "\u8f83\u4e0a\u671f",
        "\u6392\u540d",
    ]
    for label in expected_detail:
        if label not in detail_view:
            errors.append(f"FundDetailView.swift missing label: {label}")

    legacy_labels = [
        "\u6301\u4ed3\u4efd\u989d",
        "\u6210\u672c\u4ef7",
        "\u603b\u6210\u672c",
        "\u5f53\u524d\u5e02\u503c",
        "\u7d2f\u8ba1\u6d6e\u76c8",
        "\u4eca\u65e5\u53d8\u5316",
    ]
    for legacy in legacy_labels:
        if legacy in home_view or legacy in detail_view:
            errors.append(f"Legacy wording still present: {legacy}")

    settings_tokens = [
        "\u81ea\u52a8\u5237\u65b0",
        "\u81ea\u5b9a\u4e49",
        "\u5e94\u7528",
        "\u5feb\u6377\u9891\u7387",
        "\u652f\u6301 1\u20133600 \u79d2\uff0c\u9ed8\u8ba4 10 \u79d2\u3002",
    ]
    for token in settings_tokens:
        if token not in settings_view:
            errors.append(f"SettingsView.swift missing token: {token}")

    if errors:
        print("Label and auto-refresh check failed:")
        for item in errors:
            print(f"- {item}")
        return 1

    print("Label and auto-refresh check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
