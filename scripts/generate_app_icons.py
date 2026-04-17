from __future__ import annotations

import json
import shutil
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DOCS_DIR = ROOT / "docs" / "design" / "icons"
ASSET_DIR = ROOT / "src" / "zhihu" / "Assets.xcassets"
ALT_ICON_DIR = ROOT / "src" / "zhihu" / "AlternateIcons"

APP_ICON_SLOTS = [
    {"idiom": "iphone", "size": "20x20", "scale": "2x", "pixels": 40, "tag": "iphone-20@2x"},
    {"idiom": "iphone", "size": "20x20", "scale": "3x", "pixels": 60, "tag": "iphone-20@3x"},
    {"idiom": "iphone", "size": "29x29", "scale": "2x", "pixels": 58, "tag": "iphone-29@2x"},
    {"idiom": "iphone", "size": "29x29", "scale": "3x", "pixels": 87, "tag": "iphone-29@3x"},
    {"idiom": "iphone", "size": "40x40", "scale": "2x", "pixels": 80, "tag": "iphone-40@2x"},
    {"idiom": "iphone", "size": "40x40", "scale": "3x", "pixels": 120, "tag": "iphone-40@3x"},
    {"idiom": "iphone", "size": "60x60", "scale": "2x", "pixels": 120, "tag": "iphone-60@2x"},
    {"idiom": "iphone", "size": "60x60", "scale": "3x", "pixels": 180, "tag": "iphone-60@3x"},
    {"idiom": "ipad", "size": "20x20", "scale": "1x", "pixels": 20, "tag": "ipad-20@1x"},
    {"idiom": "ipad", "size": "20x20", "scale": "2x", "pixels": 40, "tag": "ipad-20@2x"},
    {"idiom": "ipad", "size": "29x29", "scale": "1x", "pixels": 29, "tag": "ipad-29@1x"},
    {"idiom": "ipad", "size": "29x29", "scale": "2x", "pixels": 58, "tag": "ipad-29@2x"},
    {"idiom": "ipad", "size": "40x40", "scale": "1x", "pixels": 40, "tag": "ipad-40@1x"},
    {"idiom": "ipad", "size": "40x40", "scale": "2x", "pixels": 80, "tag": "ipad-40@2x"},
    {"idiom": "ipad", "size": "76x76", "scale": "1x", "pixels": 76, "tag": "ipad-76@1x"},
    {"idiom": "ipad", "size": "76x76", "scale": "2x", "pixels": 152, "tag": "ipad-76@2x"},
    {"idiom": "ipad", "size": "83.5x83.5", "scale": "2x", "pixels": 167, "tag": "ipad-83p5@2x"},
    {"idiom": "ios-marketing", "size": "1024x1024", "scale": "1x", "pixels": 1024, "tag": "marketing-1024"},
]

ALT_ICON_RESOURCE_SLOTS = [
    {"base": "20", "scale": "1x", "pixels": 20},
    {"base": "20", "scale": "2x", "pixels": 40},
    {"base": "20", "scale": "3x", "pixels": 60},
    {"base": "29", "scale": "1x", "pixels": 29},
    {"base": "29", "scale": "2x", "pixels": 58},
    {"base": "29", "scale": "3x", "pixels": 87},
    {"base": "40", "scale": "1x", "pixels": 40},
    {"base": "40", "scale": "2x", "pixels": 80},
    {"base": "40", "scale": "3x", "pixels": 120},
    {"base": "60", "scale": "2x", "pixels": 120},
    {"base": "60", "scale": "3x", "pixels": 180},
    {"base": "76", "scale": "1x", "pixels": 76},
    {"base": "76", "scale": "2x", "pixels": 152},
    {"base": "83p5", "scale": "2x", "pixels": 167},
]

ICONS = {
    "ice": {
        "master": DOCS_DIR / "fund-assistant-ice-master.png",
        "app_icon_name": "AppIcon",
        "alternate_icon_name": None,
        "preview_set": "IconPreviewIce",
        "preview_file": "fund-assistant-ice-preview.png",
    },
    "deep": {
        "master": DOCS_DIR / "fund-assistant-deep-master.png",
        "app_icon_name": "AppIconDeep",
        "alternate_icon_name": "AppIconDeep",
        "preview_set": "IconPreviewDeep",
        "preview_file": "fund-assistant-deep-preview.png",
    },
    "emerald": {
        "master": DOCS_DIR / "fund-assistant-emerald-master.png",
        "app_icon_name": "AppIconEmerald",
        "alternate_icon_name": "AppIconEmerald",
        "preview_set": "IconPreviewEmerald",
        "preview_file": "fund-assistant-emerald-preview.png",
    },
}


def write_json(path: Path, payload: dict[str, object]) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def ensure_clean_dir(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def app_icon_contents(entries: list[dict[str, object]]) -> dict[str, object]:
    return {"images": entries, "info": {"author": "xcode", "version": 1}}


def image_set_contents(filename: str) -> dict[str, object]:
    return {
        "images": [{"filename": filename, "idiom": "universal", "scale": "1x"}],
        "info": {"author": "xcode", "version": 1},
    }


def resource_filename(prefix: str, base: str, scale: str) -> str:
    if scale == "1x":
        return f"{prefix}{base}.png"
    return f"{prefix}{base}@{scale}.png"


def generate_appiconset(image: Image.Image, icon_name: str) -> list[str]:
    target_dir = ASSET_DIR / f"{icon_name}.appiconset"
    ensure_clean_dir(target_dir)

    entries: list[dict[str, object]] = []
    generated: list[str] = []
    for slot in APP_ICON_SLOTS:
        filename = f"{icon_name}-{slot['tag']}.png"
        image.resize((slot['pixels'], slot['pixels']), Image.Resampling.LANCZOS).save(target_dir / filename)
        generated.append(str((target_dir / filename).relative_to(ROOT)))
        entries.append(
            {
                "filename": filename,
                "idiom": slot["idiom"],
                "size": slot["size"],
                "scale": slot["scale"],
            }
        )

    write_json(target_dir / "Contents.json", app_icon_contents(entries))
    generated.append(str((target_dir / "Contents.json").relative_to(ROOT)))
    return generated


def generate_preview(image: Image.Image, preview_set: str, preview_file: str) -> list[str]:
    target_dir = ASSET_DIR / f"{preview_set}.imageset"
    ensure_clean_dir(target_dir)
    image.save(target_dir / preview_file)
    write_json(target_dir / "Contents.json", image_set_contents(preview_file))
    return [
        str((target_dir / preview_file).relative_to(ROOT)),
        str((target_dir / "Contents.json").relative_to(ROOT)),
    ]


def generate_loose_alternate_icons(image: Image.Image, alternate_icon_name: str) -> list[str]:
    target_dir = ALT_ICON_DIR / alternate_icon_name
    ensure_clean_dir(target_dir)
    generated: list[str] = []
    for slot in ALT_ICON_RESOURCE_SLOTS:
        filename = resource_filename(alternate_icon_name, slot["base"], slot["scale"])
        image.resize((slot['pixels'], slot['pixels']), Image.Resampling.LANCZOS).save(target_dir / filename)
        generated.append(str((target_dir / filename).relative_to(ROOT)))
    return generated


def main() -> int:
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    ALT_ICON_DIR.mkdir(parents=True, exist_ok=True)
    write_json(ASSET_DIR / "Contents.json", {"info": {"author": "xcode", "version": 1}})

    generated: list[str] = []
    for config in ICONS.values():
        master_path = config["master"]
        if not master_path.exists():
            raise FileNotFoundError(f"Missing master image: {master_path}")

        image = Image.open(master_path).convert("RGBA").resize((1024, 1024), Image.Resampling.LANCZOS)
        generated.extend(generate_appiconset(image, config["app_icon_name"]))
        generated.extend(generate_preview(image, config["preview_set"], config["preview_file"]))

        alternate_icon_name = config["alternate_icon_name"]
        if alternate_icon_name:
            generated.extend(generate_loose_alternate_icons(image, alternate_icon_name))

    print("Generated app icon assets:")
    for item in generated:
        print(f"- {item}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
