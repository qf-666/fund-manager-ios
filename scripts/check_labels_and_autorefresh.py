from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def main() -> int:
    errors: list[str] = []

    app_view_model = read("src/core/AppViewModel.swift")
    app_entry = read("src/zhihu/ZhihuFundsApp.swift")
    home_view = read("src/zhihu/HomeView.swift")
    detail_view = read("src/zhihu/FundDetailView.swift")
    settings_view = read("src/zhihu/SettingsView.swift")

    for token in ["autoRefreshInterval", "startAutoRefresh", "stopAutoRefresh"]:
        if token not in app_view_model:
            errors.append(f"AppViewModel.swift missing {token}")

    if "scenePhase" not in app_entry:
        errors.append("ZhihuFundsApp.swift missing scenePhase lifecycle handling")
    if ".onChange(of: scenePhase" not in app_entry:
        errors.append("ZhihuFundsApp.swift missing scenePhase change hook")

    expected_home = [
        "持仓成本",
        "持仓市值",
        "持有份额",
        "单位成本",
    ]
    for label in expected_home:
        if label not in home_view:
            errors.append(f"HomeView.swift missing label: {label}")

    expected_detail = [
        'statPill(title: "持有份额"',
        'statPill(title: "单位成本"',
        'statPill(title: "持仓成本"',
        'statPill(title: "持仓市值"',
        'statPill(title: "累计收益"',
        'statPill(title: "今日收益"',
    ]
    for label in expected_detail:
        if label not in detail_view:
            errors.append(f"FundDetailView.swift missing token: {label}")

    for legacy in ["持仓份额", "成本价", "总成本", "当前市值", "累计浮盈", "今日变化"]:
        if legacy in home_view or legacy in detail_view:
            errors.append(f"Legacy wording still present: {legacy}")

    if "每 10 秒自动刷新" not in settings_view:
        errors.append("SettingsView.swift missing auto refresh description")

    if errors:
        print("Label and auto-refresh check failed:")
        for item in errors:
            print(f"- {item}")
        return 1

    print("Label and auto-refresh check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
