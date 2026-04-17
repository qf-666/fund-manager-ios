from __future__ import annotations

import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
DOCS_DIR = ROOT / "docs" / "design" / "icons"
ASSET_DIR = ROOT / "src" / "zhihu" / "Assets.xcassets"
ALT_ICON_DIR = ROOT / "src" / "zhihu" / "AlternateIcons"

SIZE = 1024

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

ICONS: dict[str, dict[str, object]] = {
    "ice": {
        "app_icon_name": "AppIcon",
        "alternate_icon_name": None,
        "preview_set": "IconPreviewIce",
        "doc_file": "wallet-ios26-ice",
        "bg": ["#E9F3FF", "#B7D3FF", "#CCD9FF"],
        "wallet": ["#F7FBFF", "#BFD4F6", "#6F8DC7"],
        "wallet_back": ["#F4FBFF", "#C6D9FA", "#8AA6D8"],
        "glow": "#DDEBFF",
        "accent": "#A9C7F8",
        "shadow": (120, 150, 206),
    },
    "deep": {
        "app_icon_name": "AppIconDeep",
        "alternate_icon_name": "AppIconDeep",
        "preview_set": "IconPreviewDeep",
        "doc_file": "wallet-ios26-deep",
        "bg": ["#2E395E", "#556EA8", "#7193F2"],
        "wallet": ["#EFF4FF", "#879DC7", "#516A9A"],
        "wallet_back": ["#DDE7FA", "#768AB6", "#445A86"],
        "glow": "#D8E4FF",
        "accent": "#BFD6FF",
        "shadow": (28, 42, 84),
    },
    "emerald": {
        "app_icon_name": "AppIconEmerald",
        "alternate_icon_name": "AppIconEmerald",
        "preview_set": "IconPreviewEmerald",
        "doc_file": "wallet-ios26-emerald",
        "bg": ["#D6FFF5", "#9AEFDF", "#90CCFF"],
        "wallet": ["#F5FFFD", "#BEE6E6", "#76B8C2"],
        "wallet_back": ["#F1FFFB", "#C0ECE6", "#7ABCC9"],
        "glow": "#DFFFF8",
        "accent": "#C8FFF3",
        "shadow": (76, 165, 170),
    },
}


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4))


def mix(left: tuple[int, int, int], right: tuple[int, int, int], ratio: float) -> tuple[int, int, int]:
    return tuple(round(left[index] + (right[index] - left[index]) * ratio) for index in range(3))


def rgba(color: tuple[int, int, int], alpha: int) -> tuple[int, int, int, int]:
    return color + (alpha,)


def gradient_background(top: tuple[int, int, int], middle: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE))
    pixels = image.load()
    for y in range(SIZE):
        vertical = y / (SIZE - 1)
        if vertical <= 0.52:
            base = mix(top, middle, vertical / 0.52)
        else:
            base = mix(middle, bottom, (vertical - 0.52) / 0.48)

        for x in range(SIZE):
            horizontal = x / (SIZE - 1)
            drift = (horizontal - 0.5) * 0.12
            tone = mix(base, bottom, max(0.0, min(1.0, vertical * 0.18 + drift)))
            pixels[x, y] = rgba(tone, 255)
    return image


def add_blur_ellipse(layer: Image.Image, box: tuple[int, int, int, int], color: tuple[int, int, int], alpha: int, blur: int) -> None:
    patch = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(patch)
    draw.ellipse(box, fill=rgba(color, alpha))
    layer.alpha_composite(patch.filter(ImageFilter.GaussianBlur(blur)))


def add_blur_round_rect(layer: Image.Image, box: tuple[int, int, int, int], radius: int, color: tuple[int, int, int], alpha: int, blur: int) -> None:
    patch = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(patch)
    draw.rounded_rectangle(box, radius=radius, fill=rgba(color, alpha))
    layer.alpha_composite(patch.filter(ImageFilter.GaussianBlur(blur)))


def draw_vertical_gradient_rect(image: Image.Image, box: tuple[int, int, int, int], radius: int, top: tuple[int, int, int], bottom: tuple[int, int, int], alpha_top: int, alpha_bottom: int, stroke_alpha: int) -> None:
    x1, y1, x2, y2 = box
    width = x2 - x1
    height = y2 - y1
    overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    overlay_draw = ImageDraw.Draw(overlay)
    for offset in range(height):
        ratio = offset / max(1, height - 1)
        fill = mix(top, bottom, ratio)
        alpha = round(alpha_top + (alpha_bottom - alpha_top) * ratio)
        overlay_draw.rounded_rectangle((0, offset, width, offset + 1), radius=radius, fill=rgba(fill, alpha))
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width, height), radius=radius, fill=255)
    image.paste(overlay, (x1, y1), mask)
    ImageDraw.Draw(image).rounded_rectangle(box, radius=radius, outline=(255, 255, 255, stroke_alpha), width=2)


def render_png(config: dict[str, object]) -> Image.Image:
    bg_top, bg_middle, bg_bottom = [hex_to_rgb(color) for color in config["bg"]]
    wallet_top, wallet_bottom, wallet_line = [hex_to_rgb(color) for color in config["wallet"]]
    back_top, back_bottom, _ = [hex_to_rgb(color) for color in config["wallet_back"]]
    glow = hex_to_rgb(config["glow"])
    accent = hex_to_rgb(config["accent"])
    shadow = config["shadow"]

    image = gradient_background(bg_top, bg_middle, bg_bottom)

    glow_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    add_blur_ellipse(glow_layer, (612, 18, 1016, 378), (255, 255, 255), 230, 24)
    add_blur_ellipse(glow_layer, (36, 92, 248, 304), (255, 255, 255), 84, 18)
    add_blur_ellipse(glow_layer, (-24, 694, 286, 1016), glow, 132, 42)
    add_blur_round_rect(glow_layer, (182, 88, 854, 866), 200, (255, 255, 255), 32, 30)
    image.alpha_composite(glow_layer)

    panel = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    panel_draw = ImageDraw.Draw(panel)
    panel_draw.rounded_rectangle((112, 88, 912, 912), radius=188, fill=(255, 255, 255, 28))
    panel_draw.rounded_rectangle((134, 110, 890, 890), radius=168, outline=(255, 255, 255, 54), width=2)
    panel_draw.arc((168, 70, 784, 560), start=200, end=304, fill=(255, 255, 255, 74), width=18)
    image.alpha_composite(panel)

    shadow_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    add_blur_round_rect(shadow_layer, (316, 296, 728, 568), 110, shadow, 96, 26)
    add_blur_round_rect(shadow_layer, (292, 360, 748, 640), 116, shadow, 110, 34)
    image.alpha_composite(shadow_layer)

    draw_vertical_gradient_rect(
        image,
        (318, 248, 706, 494),
        102,
        back_top,
        back_bottom,
        230,
        150,
        92,
    )
    ImageDraw.Draw(image).rounded_rectangle((356, 300, 588, 330), radius=16, fill=(255, 255, 255, 72))

    draw_vertical_gradient_rect(
        image,
        (270, 328, 734, 626),
        120,
        wallet_top,
        wallet_bottom,
        238,
        160,
        102,
    )

    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((328, 384, 552, 412), radius=14, fill=rgba(accent, 92))
    draw.line((270, 450, 734, 450), fill=rgba(wallet_line, 118), width=3)
    draw.ellipse((612, 392, 678, 458), fill=(255, 255, 255, 90))
    draw.arc((194, 588, 842, 970), start=208, end=338, fill=(255, 255, 255, 54), width=26)

    highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    add_blur_ellipse(highlight, (244, 188, 742, 372), (255, 255, 255), 44, 22)
    add_blur_ellipse(highlight, (240, 350, 740, 478), (255, 255, 255), 28, 14)
    image.alpha_composite(highlight)

    flattened = Image.new("RGB", (SIZE, SIZE), (255, 255, 255))
    flattened.paste(image, mask=image.split()[-1])
    return flattened


def render_svg(config: dict[str, object]) -> str:
    bg1, bg2, bg3 = config["bg"]
    wallet1, wallet2, wallet_line = config["wallet"]
    back1, back2, _ = config["wallet_back"]
    glow = config["glow"]
    accent = config["accent"]
    return f'''<svg width="1024" height="1024" viewBox="0 0 1024 1024" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="144" y1="84" x2="860" y2="944" gradientUnits="userSpaceOnUse">
      <stop stop-color="{bg1}"/>
      <stop offset="0.52" stop-color="{bg2}"/>
      <stop offset="1" stop-color="{bg3}"/>
    </linearGradient>
    <linearGradient id="walletFront" x1="502" y1="328" x2="502" y2="626" gradientUnits="userSpaceOnUse">
      <stop stop-color="{wallet1}" stop-opacity="0.96"/>
      <stop offset="1" stop-color="{wallet2}" stop-opacity="0.68"/>
    </linearGradient>
    <linearGradient id="walletBack" x1="512" y1="248" x2="512" y2="494" gradientUnits="userSpaceOnUse">
      <stop stop-color="{back1}" stop-opacity="0.92"/>
      <stop offset="1" stop-color="{back2}" stop-opacity="0.62"/>
    </linearGradient>
    <radialGradient id="glowTop" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(814 168) rotate(136) scale(274)">
      <stop stop-color="#FFFFFF" stop-opacity="0.94"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glowBottom" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(144 850) rotate(-18) scale(276)">
      <stop stop-color="{glow}" stop-opacity="0.88"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#bg)"/>
  <ellipse cx="814" cy="168" rx="202" ry="180" fill="url(#glowTop)"/>
  <ellipse cx="144" cy="850" rx="190" ry="172" fill="url(#glowBottom)"/>
  <ellipse cx="142" cy="198" rx="98" ry="98" fill="#FFFFFF" fill-opacity="0.22"/>
  <rect x="112" y="88" width="800" height="824" rx="188" fill="#FFFFFF" fill-opacity="0.11"/>
  <rect x="134" y="110" width="756" height="780" rx="168" stroke="#FFFFFF" stroke-opacity="0.22" stroke-width="2"/>
  <path d="M228 182C304 94 498 70 700 94C796 104 846 136 878 182" stroke="#FFFFFF" stroke-opacity="0.26" stroke-width="18" stroke-linecap="round"/>
  <rect x="318" y="248" width="388" height="246" rx="102" fill="url(#walletBack)"/>
  <rect x="318.5" y="248.5" width="387" height="245" rx="101.5" stroke="#FFFFFF" stroke-opacity="0.36"/>
  <rect x="356" y="300" width="232" height="30" rx="15" fill="#FFFFFF" fill-opacity="0.26"/>
  <rect x="270" y="328" width="464" height="298" rx="120" fill="url(#walletFront)"/>
  <rect x="270.5" y="328.5" width="463" height="297" rx="119.5" stroke="#FFFFFF" stroke-opacity="0.36"/>
  <rect x="328" y="384" width="224" height="28" rx="14" fill="{accent}" fill-opacity="0.34"/>
  <path d="M270 450H734" stroke="{wallet_line}" stroke-opacity="0.54" stroke-width="3"/>
  <circle cx="645" cy="425" r="33" fill="#FFFFFF" fill-opacity="0.36"/>
  <path d="M220 810C312 718 468 692 610 712C700 724 778 762 844 820" stroke="#FFFFFF" stroke-opacity="0.22" stroke-width="26" stroke-linecap="round"/>
</svg>'''


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


def main() -> int:
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    ALT_ICON_DIR.mkdir(parents=True, exist_ok=True)

    for folder_name in ["AppIcon.appiconset", "AppIconDeep.appiconset", "AppIconEmerald.appiconset"]:
        target = ASSET_DIR / folder_name
        if target.exists():
            shutil.rmtree(target)

    for folder_name in ["IconPreviewIce.imageset", "IconPreviewDeep.imageset", "IconPreviewEmerald.imageset"]:
        target = ASSET_DIR / folder_name
        if target.exists():
            shutil.rmtree(target)

    for folder_name in ["AppIconDeep", "AppIconEmerald"]:
        target = ALT_ICON_DIR / folder_name
        if target.exists():
            shutil.rmtree(target)

    write_json(ASSET_DIR / "Contents.json", {"info": {"author": "xcode", "version": 1}})

    generated: list[str] = []

    primary_icon_dir = ASSET_DIR / "AppIcon.appiconset"
    ensure_clean_dir(primary_icon_dir)
    primary_contents: list[dict[str, object]] = []

    for key, config in ICONS.items():
        image = render_png(config)

        svg_path = DOCS_DIR / f"{config['doc_file']}.svg"
        svg_path.write_text(render_svg(config), encoding="utf-8")
        generated.append(str(svg_path.relative_to(ROOT)))

        preview_dir = ASSET_DIR / f"{config['preview_set']}.imageset"
        ensure_clean_dir(preview_dir)
        preview_name = f"{config['doc_file']}-preview.png"
        image.save(preview_dir / preview_name)
        write_json(preview_dir / "Contents.json", image_set_contents(preview_name))
        generated.append(str((preview_dir / preview_name).relative_to(ROOT)))

        if key == "ice":
            for slot in APP_ICON_SLOTS:
                filename = f"AppIcon-{slot['tag']}.png"
                image.resize((slot['pixels'], slot['pixels']), Image.Resampling.LANCZOS).save(primary_icon_dir / filename)
                generated.append(str((primary_icon_dir / filename).relative_to(ROOT)))
                primary_contents.append(
                    {
                        "filename": filename,
                        "idiom": slot["idiom"],
                        "size": slot["size"],
                        "scale": slot["scale"],
                    }
                )
        else:
            resource_dir = ALT_ICON_DIR / str(config["alternate_icon_name"])
            ensure_clean_dir(resource_dir)
            for slot in ALT_ICON_RESOURCE_SLOTS:
                filename = resource_filename(str(config["alternate_icon_name"]), slot["base"], slot["scale"])
                image.resize((slot['pixels'], slot['pixels']), Image.Resampling.LANCZOS).save(resource_dir / filename)
                generated.append(str((resource_dir / filename).relative_to(ROOT)))

    write_json(primary_icon_dir / "Contents.json", app_icon_contents(primary_contents))

    print("Generated app icon assets:")
    for item in generated:
        print(f"- {item}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
