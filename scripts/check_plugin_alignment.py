from __future__ import annotations

import math
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def plugin_like_values(
    *,
    nav: float,
    report_date: str,
    shares: float,
    cost: float,
    daily_nav_change_percent: float | None = None,
    estimated_nav: float | None = None,
    estimated_change_percent: float | None = None,
    estimated_time: str | None = None,
):
    same_day = bool(estimated_time) and report_date == estimated_time[:10]

    if same_day:
        display_price = nav
        display_change_percent = daily_nav_change_percent
        daily_pnl = (nav - nav / (1 + (daily_nav_change_percent or 0) / 100)) * shares
    else:
        display_price = estimated_nav if estimated_nav is not None else nav
        display_change_percent = (
            estimated_change_percent
            if estimated_change_percent is not None
            else daily_nav_change_percent
        )
        daily_pnl = (
            ((estimated_nav - nav) * shares)
            if estimated_nav is not None
            else 0.0
        )

    market_value = nav * shares
    total_pnl = (nav - cost) * shares
    return display_price, display_change_percent, market_value, total_pnl, daily_pnl


def approx_equal(left: float, right: float, tolerance: float = 0.05) -> bool:
    return math.isclose(left, right, abs_tol=tolerance)


def main() -> int:
    errors: list[str] = []

    models = read("src/core/Models.swift")
    app_view_model = read("src/core/AppViewModel.swift")
    api = read("src/core/EastMoneyAPI.swift")
    home = read("src/zhihu/HomeView.swift")

    required_model_tokens = [
        "var prefersOfficialSnapshot: Bool",
        "var marketValuePrice: Double?",
        "var dailyPnLPerUnit: Double?",
    ]
    for token in required_model_tokens:
        if token not in models:
            errors.append(f"Models.swift missing {token}")

    if "quote(for: holding.code)?.marketValuePrice" not in app_view_model:
        errors.append("AppViewModel.swift should use marketValuePrice for position value")

    if "quote(for: holding.code)?.dailyPnLPerUnit" not in app_view_model:
        errors.append("AppViewModel.swift should use per-unit daily gain for today PnL")

    if "marketValue * changePercent / 100" in app_view_model:
        errors.append("AppViewModel.swift still uses marketValue * percent for today PnL")

    required_api_tokens = [
        "fundgz.1234567.com.cn/js/",
        "fetchFallbackEstimates",
        "let fallbackEstimates = await fetchFallbackEstimates(for: snapshots)",
    ]
    for token in required_api_tokens:
        if token not in api:
            errors.append(f"EastMoneyAPI.swift missing {token}")

    if "shouldFetchFallbackEstimates" in api:
        errors.append("EastMoneyAPI.swift should not gate fallback estimates by trading hours")

    if "按已确认净值计算" not in home:
        errors.append("HomeView.swift should clarify that持仓市值 uses confirmed NAV")

    official_display = plugin_like_values(
        nav=1.3394,
        report_date="2026-04-16",
        shares=703.11,
        cost=1.3029,
        daily_nav_change_percent=2.90,
        estimated_nav=1.3403,
        estimated_change_percent=2.97,
        estimated_time="2026-04-16 15:00",
    )
    if not approx_equal(official_display[0], 1.3394):
        errors.append("Expected same-day official quote to display NAV 1.3394")
    if not approx_equal(official_display[2], 941.75):
        errors.append("Expected same-day official market value to be about 941.75")
    if not approx_equal(official_display[3], 25.66):
        errors.append("Expected same-day official total PnL to be about 25.66")
    if not approx_equal(official_display[4], 26.58):
        errors.append("Expected same-day official daily PnL to be about 26.58")

    estimated_display = plugin_like_values(
        nav=1.5155,
        report_date="2026-04-15",
        shares=72.05,
        cost=1.499,
        daily_nav_change_percent=-1.07,
        estimated_nav=1.5463,
        estimated_change_percent=2.03,
        estimated_time="2026-04-16 15:00",
    )
    if not approx_equal(estimated_display[0], 1.5463):
        errors.append("Expected stale official quote to display estimate 1.5463")
    if not approx_equal(estimated_display[2], 109.19):
        errors.append("Expected stale official market value to be about 109.19")
    if not approx_equal(estimated_display[3], 1.19):
        errors.append("Expected stale official total PnL to be about 1.19")
    if not approx_equal(estimated_display[4], 2.22):
        errors.append("Expected stale official daily PnL to be about 2.22")

    if errors:
        print("Plugin alignment check failed:")
        for item in errors:
            print(f"- {item}")
        return 1

    print("Plugin alignment check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
