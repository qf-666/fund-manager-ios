from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def exists(path: str) -> bool:
    return (ROOT / path).exists()


def main() -> int:
    errors: list[str] = []

    project = read("project.yml")
    models = read("src/core/Models.swift")
    view_model = read("src/core/AppViewModel.swift")
    settings = read("src/zhihu/SettingsView.swift")
    app = read("src/zhihu/ZhihuFundsApp.swift")

    project_tokens = [
        "ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon",
        "ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES: AppIconDeep AppIconEmerald",
        "CFBundleDisplayName: 基金助手",
    ]
    for token in project_tokens:
        if token not in project:
            errors.append(f"project.yml missing {token}")

    model_tokens = [
        "enum AppIconOption",
        "var appIcon: AppIconOption",
        'case .ice: return "IconPreviewIce"',
        'case .deep: return "IconPreviewDeep"',
        'case .emerald: return "IconPreviewEmerald"',
        "appIcon = try container.decodeIfPresent(AppIconOption.self, forKey: .appIcon) ?? .ice",
        "appIcon: .ice",
    ]
    for token in model_tokens:
        if token not in models:
            errors.append(f"Models.swift missing {token}")

    view_model_tokens = [
        "var supportsAlternateIcons: Bool",
        "func setAppIcon(_ icon: AppIconOption)",
        "func syncAppIcon()",
        "UIApplication.shared.setAlternateIconName",
        "formatAppIconError",
        "固定图标版本",
    ]
    for token in view_model_tokens:
        if token not in view_model:
            errors.append(f"AppViewModel.swift missing {token}")

    settings_tokens = [
        'Section("应用图标")',
        "AppIconOption.allCases",
        "Image(option.previewAssetName)",
        "viewModel.supportsAlternateIcons",
        "viewModel.setAppIcon",
        "固定图标版本",
    ]
    for token in settings_tokens:
        if token not in settings:
            errors.append(f"SettingsView.swift missing {token}")

    if "await viewModel.syncAppIcon()" not in app:
        errors.append("ZhihuFundsApp.swift should sync app icon on launch")

    required_files = [
        "scripts/generate_app_icons.py",
        "docs/design/icons/fund-assistant-ice-master.png",
        "docs/design/icons/fund-assistant-deep-master.png",
        "docs/design/icons/fund-assistant-emerald-master.png",
        "src/zhihu/Assets.xcassets/Contents.json",
        "src/zhihu/Assets.xcassets/AppIcon.appiconset/Contents.json",
        "src/zhihu/Assets.xcassets/AppIconDeep.appiconset/Contents.json",
        "src/zhihu/Assets.xcassets/AppIconEmerald.appiconset/Contents.json",
        "src/zhihu/Assets.xcassets/IconPreviewIce.imageset/Contents.json",
        "src/zhihu/Assets.xcassets/IconPreviewDeep.imageset/Contents.json",
        "src/zhihu/Assets.xcassets/IconPreviewEmerald.imageset/Contents.json",
        "src/zhihu/AlternateIcons/AppIconDeep/AppIconDeep60@2x.png",
        "src/zhihu/AlternateIcons/AppIconDeep/AppIconDeep76@2x.png",
        "src/zhihu/AlternateIcons/AppIconEmerald/AppIconEmerald60@2x.png",
        "src/zhihu/AlternateIcons/AppIconEmerald/AppIconEmerald76@2x.png",
    ]
    for path in required_files:
        if not exists(path):
            errors.append(f"Missing file: {path}")

    if errors:
        print("App icon setup check failed:")
        for item in errors:
            print(f"- {item}")
        return 1

    print("App icon setup check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
