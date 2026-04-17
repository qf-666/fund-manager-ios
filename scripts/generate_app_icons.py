from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
DOCS_DIR = ROOT / "docs" / "design" / "icons"
ASSET_DIR = ROOT / "src" / "zhihu" / "Assets.xcassets"

SIZE = 1024

ICONS: dict[str, dict[str, object]] = {
    "ice": {
        "title": "冰川钱包",
        "app_icon_set": "AppIcon",
        "preview_set": "IconPreviewIce",
        "base_file": "wallet-ios26-ice",
        "bg": ["#E8F4FF", "#94C6FF", "#CDD7FF"],
        "glow": "#C4E1FF",
        "shadow": (17, 30, 51),
        "bar": ["#FFFFFF", "#DAECFF"],
    },
    "deep": {
        "title": "深空资产卡",
        "app_icon_set": "AppIconDeep",
        "preview_set": "IconPreviewDeep",
        "base_file": "wallet-ios26-deep",
        "bg": ["#121826", "#2A3E72", "#79A9FF"],
        "glow": "#6294FF",
        "shadow": (2, 10, 24),
        "bar": ["#FFFFFF", "#C1DFFF"],
    },
    "emerald": {
        "title": "翡翠流光",
        "app_icon_set": "AppIconEmerald",
        "preview_set": "IconPreviewEmerald",
        "base_file": "wallet-ios26-emerald",
        "bg": ["#D9FFF2", "#84E4CE", "#8DBFFF"],
        "glow": "#81F1D8",
        "shadow": (8, 32, 30),
        "bar": ["#FFFFFF", "#C6FFEE"],
    },
}


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[index : index + 2], 16) for index in (0, 2, 4))


def rgba(color: tuple[int, int, int], alpha: int) -> tuple[int, int, int, int]:
    return color + (alpha,)


def mix(left: tuple[int, int, int], right: tuple[int, int, int], ratio: float) -> tuple[int, int, int]:
    return tuple(round(left[index] + (right[index] - left[index]) * ratio) for index in range(3))


def multi_stop_gradient(stops: list[tuple[float, tuple[int, int, int]]], height: int) -> Image.Image:
    image = Image.new("RGBA", (SIZE, height))
    pixels = image.load()
    for y in range(height):
        position = y / max(1, height - 1)
        for index, (stop, color) in enumerate(stops):
            if position <= stop:
                previous_stop, previous_color = stops[max(0, index - 1)]
                local_range = max(0.0001, stop - previous_stop)
                local_ratio = 0 if index == 0 else (position - previous_stop) / local_range
                mixed = mix(previous_color, color, max(0.0, min(1.0, local_ratio)))
                for x in range(SIZE):
                    pixels[x, y] = rgba(mixed, 255)
                break
    return image


def add_blurred_circle(layer: Image.Image, bbox: tuple[int, int, int, int], color: tuple[int, int, int], alpha: int, blur: int) -> None:
    circle = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(circle)
    draw.ellipse(bbox, fill=rgba(color, alpha))
    blurred = circle.filter(ImageFilter.GaussianBlur(blur))
    layer.alpha_composite(blurred)


def rounded_rect_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def draw_bar_gradient(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], top_color: tuple[int, int, int], bottom_color: tuple[int, int, int]) -> None:
    x1, y1, x2, y2 = box
    height = max(1, y2 - y1)
    for offset in range(height):
        ratio = offset / max(1, height - 1)
        fill = mix(top_color, bottom_color, ratio)
        draw.rounded_rectangle((x1, y1 + offset, x2, y1 + offset + 1), radius=max(1, (x2 - x1) // 2), fill=fill)


def render_png(config: dict[str, object]) -> Image.Image:
    bg_colors = [hex_to_rgb(color) for color in config["bg"]]  # type: ignore[index]
    glow_color = hex_to_rgb(config["glow"])  # type: ignore[arg-type]
    shadow_color = config["shadow"]  # type: ignore[assignment]
    bar_top, bar_bottom = [hex_to_rgb(color) for color in config["bar"]]  # type: ignore[index]

    base = multi_stop_gradient(
        [(0.0, bg_colors[0]), (0.48, bg_colors[1]), (1.0, bg_colors[2])],
        SIZE,
    )

    glow_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    add_blurred_circle(glow_layer, (620, 36, 996, 412), (255, 255, 255), 220, 28)
    add_blurred_circle(glow_layer, (40, 620, 430, 1010), glow_color, 180, 36)
    add_blurred_circle(glow_layer, (112, 192, 292, 372), (255, 255, 255), 36, 16)
    base.alpha_composite(glow_layer)

    frame = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    frame_draw = ImageDraw.Draw(frame)
    frame_draw.rounded_rectangle((84, 84, 940, 940), radius=196, fill=(255, 255, 255, 18))
    frame_draw.rounded_rectangle((106, 106, 918, 918), radius=174, outline=(255, 255, 255, 42), width=2)
    base.alpha_composite(frame)

    icon_shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(icon_shadow)
    shadow_draw.rounded_rectangle((240, 520, 784, 768), radius=112, fill=shadow_color + (70,))
    icon_shadow = icon_shadow.filter(ImageFilter.GaussianBlur(34))
    base.alpha_composite(icon_shadow)

    card = Image.new("RGBA", (480, 320), (0, 0, 0, 0))
    card_draw = ImageDraw.Draw(card)
    card_draw.rounded_rectangle((32, 20, 448, 284), radius=92, fill=(255, 255, 255, 58))
    card_draw.rounded_rectangle((32, 20, 448, 284), radius=92, fill=(255, 255, 255, 168))
    card_draw.rounded_rectangle((33, 21, 447, 283), radius=91, outline=(255, 255, 255, 92), width=2)
    card_draw.rounded_rectangle((90, 80, 218, 108), radius=14, fill=(255, 255, 255, 160))
    bar_positions = [
        (90, 176, 128, 218),
        (140, 152, 178, 218),
        (190, 122, 228, 218),
        (240, 138, 278, 218),
        (290, 106, 328, 218),
    ]
    for position in bar_positions:
        draw_bar_gradient(card_draw, position, bar_top, bar_bottom)
    card = card.rotate(-8, resample=Image.Resampling.BICUBIC, expand=True)
    base.alpha_composite(card, (250, 150))

    wallet = Image.new("RGBA", (640, 340), (0, 0, 0, 0))
    wallet_draw = ImageDraw.Draw(wallet)
    wallet_draw.rounded_rectangle((48, 56, 592, 304), radius=112, fill=(255, 255, 255, 34))
    wallet_draw.rounded_rectangle((48, 56, 592, 304), radius=112, fill=(255, 255, 255, 118))
    wallet_draw.rounded_rectangle((49, 57, 591, 303), radius=111, outline=(255, 255, 255, 86), width=2)
    wallet_draw.rounded_rectangle((130, 126, 348, 148), radius=12, fill=(255, 255, 255, 56))
    wallet_draw.ellipse((474, 122, 542, 190), fill=(255, 255, 255, 70))
    wallet_draw.line((48, 142, 592, 142), fill=(255, 255, 255, 34), width=2)
    base.alpha_composite(wallet, (168, 430))

    bottom_curve = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    bottom_draw = ImageDraw.Draw(bottom_curve)
    bottom_draw.arc((120, 626, 900, 946), start=196, end=343, fill=(255, 255, 255, 42), width=28)
    base.alpha_composite(bottom_curve)

    flattened = Image.new("RGB", (SIZE, SIZE), (255, 255, 255))
    flattened.paste(base, mask=base.split()[-1])
    return flattened


def render_svg(config: dict[str, object]) -> str:
    bg1, bg2, bg3 = config["bg"]  # type: ignore[misc]
    glow = config["glow"]  # type: ignore[assignment]
    bar1, bar2 = config["bar"]  # type: ignore[misc]
    return f"""<svg width=\"1024\" height=\"1024\" viewBox=\"0 0 1024 1024\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\">
  <defs>
    <linearGradient id=\"bg\" x1=\"140\" y1=\"108\" x2=\"896\" y2=\"924\" gradientUnits=\"userSpaceOnUse\">
      <stop stop-color=\"{bg1}\"/>
      <stop offset=\"0.48\" stop-color=\"{bg2}\"/>
      <stop offset=\"1\" stop-color=\"{bg3}\"/>
    </linearGradient>
    <linearGradient id=\"miniBar\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\">
      <stop stop-color=\"{bar1}\"/>
      <stop offset=\"1\" stop-color=\"{bar2}\"/>
    </linearGradient>
    <radialGradient id=\"glowTop\" cx=\"0\" cy=\"0\" r=\"1\" gradientUnits=\"userSpaceOnUse\" gradientTransform=\"translate(782 186) rotate(131.482) scale(362.768)\">
      <stop stop-color=\"#FFFFFF\" stop-opacity=\"0.92\"/>
      <stop offset=\"1\" stop-color=\"#FFFFFF\" stop-opacity=\"0\"/>
    </radialGradient>
    <radialGradient id=\"glowBottom\" cx=\"0\" cy=\"0\" r=\"1\" gradientUnits=\"userSpaceOnUse\" gradientTransform=\"translate(244 794) rotate(-33.8338) scale(348.927)\">
      <stop stop-color=\"{glow}\" stop-opacity=\"0.72\"/>
      <stop offset=\"1\" stop-color=\"#FFFFFF\" stop-opacity=\"0\"/>
    </radialGradient>
  </defs>
  <rect width=\"1024\" height=\"1024\" fill=\"url(#bg)\"/>
  <circle cx=\"782\" cy=\"186\" r=\"184\" fill=\"url(#glowTop)\"/>
  <circle cx=\"244\" cy=\"794\" r=\"188\" fill=\"url(#glowBottom)\"/>
  <circle cx=\"202\" cy=\"282\" r=\"82\" fill=\"#FFFFFF\" fill-opacity=\"0.12\"/>
  <rect x=\"84\" y=\"84\" width=\"856\" height=\"856\" rx=\"196\" fill=\"#FFFFFF\" fill-opacity=\"0.08\"/>
  <rect x=\"106\" y=\"106\" width=\"812\" height=\"812\" rx=\"174\" stroke=\"#FFFFFF\" stroke-opacity=\"0.16\" stroke-width=\"2\"/>
  <g transform=\"translate(0 -6) rotate(-8 512 382)\">
    <rect x=\"306\" y=\"232\" width=\"414\" height=\"264\" rx=\"92\" fill=\"#FFFFFF\" fill-opacity=\"0.18\"/>
    <rect x=\"306\" y=\"232\" width=\"414\" height=\"264\" rx=\"92\" fill=\"#FFFFFF\" fill-opacity=\"0.48\"/>
    <rect x=\"306.5\" y=\"232.5\" width=\"413\" height=\"263\" rx=\"91.5\" stroke=\"#FFFFFF\" stroke-opacity=\"0.36\"/>
    <rect x=\"364\" y=\"292\" width=\"126\" height=\"26\" rx=\"13\" fill=\"#FFFFFF\" fill-opacity=\"0.58\"/>
    <rect x=\"364\" y=\"384\" width=\"38\" height=\"42\" rx=\"19\" fill=\"url(#miniBar)\"/>
    <rect x=\"414\" y=\"360\" width=\"38\" height=\"66\" rx=\"19\" fill=\"url(#miniBar)\"/>
    <rect x=\"464\" y=\"330\" width=\"38\" height=\"96\" rx=\"19\" fill=\"url(#miniBar)\"/>
    <rect x=\"514\" y=\"346\" width=\"38\" height=\"80\" rx=\"19\" fill=\"url(#miniBar)\"/>
    <rect x=\"564\" y=\"314\" width=\"38\" height=\"112\" rx=\"19\" fill=\"url(#miniBar)\"/>
  </g>
  <rect x=\"240\" y=\"520\" width=\"544\" height=\"248\" rx=\"112\" fill=\"#FFFFFF\" fill-opacity=\"0.14\"/>
  <rect x=\"240\" y=\"520\" width=\"544\" height=\"248\" rx=\"112\" fill=\"#FFFFFF\" fill-opacity=\"0.30\"/>
  <rect x=\"240.5\" y=\"520.5\" width=\"543\" height=\"247\" rx=\"111.5\" stroke=\"#FFFFFF\" stroke-opacity=\"0.34\"/>
  <rect x=\"322\" y=\"590\" width=\"218\" height=\"22\" rx=\"11\" fill=\"#FFFFFF\" fill-opacity=\"0.22\"/>
  <circle cx=\"682\" cy=\"640\" r=\"34\" fill=\"#FFFFFF\" fill-opacity=\"0.28\"/>
  <path d=\"M240 606H784\" stroke=\"#FFFFFF\" stroke-opacity=\"0.12\" stroke-width=\"2\"/>
  <path d=\"M168 764C280 706 405 694 520 710C634 726 729 774 839 838\" stroke=\"#FFFFFF\" stroke-opacity=\"0.18\" stroke-width=\"28\" stroke-linecap=\"round\"/>
</svg>
"""


def write_json(path: Path, payload: dict[str, object]) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def app_icon_contents(filename: str) -> dict[str, object]:
    return {
        "images": [
            {
                "filename": filename,
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            }
        ],
        "info": {"author": "xcode", "version": 1},
    }


def image_set_contents(filename: str) -> dict[str, object]:
    return {
        "images": [
            {
                "filename": filename,
                "idiom": "universal",
                "scale": "1x",
            }
        ],
        "info": {"author": "xcode", "version": 1},
    }


def main() -> int:
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    write_json(ASSET_DIR / "Contents.json", {"info": {"author": "xcode", "version": 1}})

    generated: list[str] = []

    for config in ICONS.values():
        svg_name = f"{config['base_file']}.svg"
        svg_path = DOCS_DIR / svg_name
        svg_path.write_text(render_svg(config), encoding="utf-8")
        generated.append(str(svg_path.relative_to(ROOT)))

        image = render_png(config)

        app_icon_dir = ASSET_DIR / f"{config['app_icon_set']}.appiconset"
        app_icon_dir.mkdir(parents=True, exist_ok=True)
        app_icon_name = f"{config['base_file']}-1024.png"
        image.save(app_icon_dir / app_icon_name)
        write_json(app_icon_dir / "Contents.json", app_icon_contents(app_icon_name))
        generated.append(str((app_icon_dir / app_icon_name).relative_to(ROOT)))

        preview_dir = ASSET_DIR / f"{config['preview_set']}.imageset"
        preview_dir.mkdir(parents=True, exist_ok=True)
        preview_name = f"{config['base_file']}-preview.png"
        image.save(preview_dir / preview_name)
        write_json(preview_dir / "Contents.json", image_set_contents(preview_name))
        generated.append(str((preview_dir / preview_name).relative_to(ROOT)))

    print("Generated app icon assets:")
    for item in generated:
        print(f"- {item}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
