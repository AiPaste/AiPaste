#!/usr/bin/env python3
from __future__ import annotations

import math
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parent.parent
ASSETS_DIR = ROOT / "Assets"
ICONSET_DIR = ASSETS_DIR / "AppIcon.iconset"
MASTER_PNG = ASSETS_DIR / "AppIcon-1024.png"
ICNS_PATH = ASSETS_DIR / "AppIcon.icns"


def rounded_rect_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def diagonal_gradient(size: int, colors: list[tuple[int, int, int]]) -> Image.Image:
    img = Image.new("RGBA", (size, size))
    px = img.load()
    steps = len(colors) - 1
    for y in range(size):
        for x in range(size):
            t = (x * 0.55 + y * 0.95) / ((size - 1) * 1.5)
            t = max(0.0, min(1.0, t))
            idx = min(int(t * steps), steps - 1)
            local_t = (t - idx / steps) * steps
            c0 = colors[idx]
            c1 = colors[idx + 1]
            px[x, y] = (
                int(c0[0] + (c1[0] - c0[0]) * local_t),
                int(c0[1] + (c1[1] - c0[1]) * local_t),
                int(c0[2] + (c1[2] - c0[2]) * local_t),
                255,
            )
    return img


def radial_glow(size: int, center: tuple[float, float], radius: float, color: tuple[int, int, int, int]) -> Image.Image:
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = layer.load()
    cx, cy = center
    for y in range(size):
        for x in range(size):
            dx = x - cx
            dy = y - cy
            dist = math.hypot(dx, dy) / radius
            if dist >= 1:
                continue
            alpha = int((1 - dist) ** 2.4 * color[3])
            px[x, y] = (color[0], color[1], color[2], alpha)
    return layer.filter(ImageFilter.GaussianBlur(radius=size * 0.015))


def add_shadow(base: Image.Image, shape_bbox: tuple[int, int, int, int], radius: int, offset: tuple[int, int], opacity: int) -> Image.Image:
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    mask = Image.new("L", base.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(shape_bbox, radius=radius, fill=opacity)
    mask = mask.filter(ImageFilter.GaussianBlur(radius=28))
    shadow.putalpha(mask)
    shifted = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shifted.alpha_composite(shadow, dest=offset)
    return Image.alpha_composite(base, shifted)


def draw_card(draw: ImageDraw.ImageDraw, bbox: tuple[int, int, int, int], fill: tuple[int, int, int, int], outline: tuple[int, int, int, int], radius: int) -> None:
    draw.rounded_rectangle(bbox, radius=radius, fill=fill, outline=outline, width=3)


def generate_master_icon() -> Image.Image:
    size = 1024
    canvas = diagonal_gradient(
        size,
        [
            (18, 25, 43),
            (27, 39, 68),
            (29, 78, 156),
            (39, 198, 181),
        ],
    )

    mask = rounded_rect_mask(size, 232)
    canvas.putalpha(mask)

    canvas = Image.alpha_composite(canvas, radial_glow(size, (220, 180), 520, (126, 176, 255, 105)))
    canvas = Image.alpha_composite(canvas, radial_glow(size, (800, 860), 460, (20, 255, 208, 85)))
    canvas = Image.alpha_composite(canvas, radial_glow(size, (770, 250), 250, (255, 145, 54, 85)))

    inner_border = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner_draw = ImageDraw.Draw(inner_border)
    inner_draw.rounded_rectangle(
        (18, 18, size - 18, size - 18),
        radius=214,
        outline=(255, 255, 255, 50),
        width=4,
    )
    canvas = Image.alpha_composite(canvas, inner_border)

    canvas = add_shadow(canvas, (220, 270, 746, 760), 120, (0, 14), 70)
    canvas = add_shadow(canvas, (284, 212, 810, 700), 120, (0, 6), 58)
    canvas = add_shadow(canvas, (348, 156, 874, 640), 120, (0, 0), 50)

    draw = ImageDraw.Draw(canvas)

    card_fill = (245, 249, 255, 220)
    card_outline = (255, 255, 255, 95)
    draw_card(draw, (220, 270, 746, 760), card_fill, card_outline, 118)
    draw_card(draw, (284, 212, 810, 700), card_fill, card_outline, 118)
    draw_card(draw, (348, 156, 874, 640), (255, 255, 255, 236), (255, 255, 255, 110), 118)

    for stripe_y in (250, 320, 390):
        draw.rounded_rectangle((448, stripe_y, 712, stripe_y + 22), radius=11, fill=(53, 93, 184, 44))

    clip_shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    clip_draw = ImageDraw.Draw(clip_shadow)
    clip_draw.rounded_rectangle((434, 90, 790, 282), radius=96, fill=(0, 0, 0, 155))
    clip_shadow = clip_shadow.filter(ImageFilter.GaussianBlur(radius=36))
    canvas = Image.alpha_composite(canvas, clip_shadow)

    clip_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    clip_draw = ImageDraw.Draw(clip_layer)
    clip_draw.rounded_rectangle((434, 100, 790, 292), radius=96, fill=(255, 157, 44, 255))
    clip_draw.rounded_rectangle((486, 128, 738, 214), radius=44, fill=(255, 218, 163, 235))
    clip_draw.rounded_rectangle((554, 78, 670, 150), radius=34, fill=(255, 186, 86, 250))
    clip_draw.rounded_rectangle((576, 102, 648, 136), radius=17, fill=(255, 237, 198, 255))
    clip_layer = Image.alpha_composite(clip_layer, radial_glow(size, (700, 130), 240, (255, 244, 202, 110)))
    canvas = Image.alpha_composite(canvas, clip_layer)

    sweep = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sweep_draw = ImageDraw.Draw(sweep)
    sweep_draw.rounded_rectangle((345, 408, 448, 575), radius=30, fill=(255, 242, 230, 255))
    sweep_draw.rounded_rectangle((430, 430, 655, 477), radius=22, fill=(111, 170, 255, 255))
    sweep_draw.rounded_rectangle((430, 498, 625, 545), radius=22, fill=(65, 120, 227, 245))
    sweep = sweep.filter(ImageFilter.GaussianBlur(radius=0.25))
    canvas = Image.alpha_composite(canvas, sweep)

    ribbon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ribbon_draw = ImageDraw.Draw(ribbon)
    ribbon_draw.rounded_rectangle((310, 420, 410, 626), radius=42, fill=(255, 252, 245, 255))
    ribbon_draw.pieslice((280, 300, 575, 630), 152, 250, fill=(255, 255, 255, 0), outline=(255, 238, 223, 255), width=46)
    ribbon = ribbon.filter(ImageFilter.GaussianBlur(radius=1.0))
    canvas = Image.alpha_composite(canvas, ribbon)

    highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(highlight)
    hdraw.rounded_rectangle((86, 86, 938, 410), radius=164, fill=(255, 255, 255, 28))
    highlight = highlight.filter(ImageFilter.GaussianBlur(radius=70))
    canvas = Image.alpha_composite(canvas, highlight)

    alpha = canvas.getchannel("A")
    rgb = canvas.convert("RGB")
    rgb.putalpha(alpha)
    return rgb


def save_iconset(master: Image.Image) -> None:
    if ICONSET_DIR.exists():
        shutil.rmtree(ICONSET_DIR)
    ICONSET_DIR.mkdir(parents=True, exist_ok=True)

    sizes = [16, 32, 64, 128, 256, 512, 1024]
    for size in sizes:
        image = master.resize((size, size), Image.Resampling.LANCZOS)
        image.save(ICONSET_DIR / f"icon_{size}x{size}.png")
        if size < 1024:
            image_2x = master.resize((size * 2, size * 2), Image.Resampling.LANCZOS)
            image_2x.save(ICONSET_DIR / f"icon_{size}x{size}@2x.png")


def build_icns() -> None:
    if shutil.which("iconutil") is None:
        raise RuntimeError("iconutil is required to build AppIcon.icns")
    if ICNS_PATH.exists():
        ICNS_PATH.unlink()
    subprocess.run(
        ["iconutil", "-c", "icns", str(ICONSET_DIR), "-o", str(ICNS_PATH)],
        check=True,
    )


def main() -> None:
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)
    master = generate_master_icon()
    master.save(MASTER_PNG)
    save_iconset(master)
    build_icns()
    print(f"Generated {MASTER_PNG}")
    print(f"Generated {ICNS_PATH}")


if __name__ == "__main__":
    main()
