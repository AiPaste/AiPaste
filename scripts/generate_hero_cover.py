#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from typing import Tuple

from PIL import Image, ImageColor, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "docs" / "assets" / "hero-cover.png"
ICON_PATH = ROOT / "docs" / "assets" / "app-icon.png"
PHILOSOPHY_PATH = ROOT / "docs" / "assets" / "hero-cover-philosophy.md"

WIDTH = 2386
HEIGHT = 1206


def load_font(size: int, *, mono: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Supplemental/Menlo.ttc" if mono else "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    ]
    for candidate in candidates:
        path = Path(candidate)
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def rounded_box(draw: ImageDraw.ImageDraw, box: Tuple[int, int, int, int], fill, radius: int, outline=None, width: int = 1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def shadow_layer(size: Tuple[int, int], box: Tuple[int, int, int, int], *, radius: int, blur: int, color: Tuple[int, int, int, int]) -> Image.Image:
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    layer_draw = ImageDraw.Draw(layer)
    layer_draw.rounded_rectangle(box, radius=radius, fill=color)
    return layer.filter(ImageFilter.GaussianBlur(blur))


def text(draw: ImageDraw.ImageDraw, xy, value: str, font, fill, anchor=None):
    draw.text(xy, value, font=font, fill=fill, anchor=anchor)


def multiline_block(draw: ImageDraw.ImageDraw, x: int, y: int, lines: list[str], font, fill, line_gap: int):
    cursor = y
    for line in lines:
        draw.text((x, cursor), line, font=font, fill=fill)
        bbox = draw.textbbox((x, cursor), line, font=font)
        cursor = bbox[3] + line_gap
    return cursor


def create_background() -> Image.Image:
    base = Image.new("RGBA", (WIDTH, HEIGHT), "#fbfaf7")
    pixels = base.load()
    top = ImageColor.getrgb("#fcfbf8")
    bottom = ImageColor.getrgb("#f4f3ef")
    for y in range(HEIGHT):
        t = y / (HEIGHT - 1)
        row = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        for x in range(WIDTH):
            pixels[x, y] = (*row, 255)

    glow = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse((-120, -40, 700, 780), fill=(169, 226, 207, 72))
    glow_draw.ellipse((1600, 40, 2440, 820), fill=(255, 206, 128, 68))
    glow_draw.ellipse((820, 120, 1620, 920), fill=(255, 255, 255, 118))
    glow = glow.filter(ImageFilter.GaussianBlur(90))
    return Image.alpha_composite(base, glow)


def draw_macbook(canvas: Image.Image) -> None:
    draw = ImageDraw.Draw(canvas)
    screen_box = (460, 150, 1918, 916)
    screen_radius = 36
    bezel = 18

    canvas.alpha_composite(shadow_layer(canvas.size, (440, 160, 1940, 948), radius=44, blur=40, color=(19, 26, 36, 50)))
    rounded_box(draw, screen_box, "#101114", screen_radius, outline="#20242d", width=2)

    notch_box = (1114, 152, 1264, 216)
    rounded_box(draw, notch_box, "#0b0b0d", 24)

    inner = (
        screen_box[0] + bezel,
        screen_box[1] + bezel,
        screen_box[2] - bezel,
        screen_box[3] - bezel,
    )
    screen = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    screen_draw = ImageDraw.Draw(screen)
    rounded_box(screen_draw, inner, "#f7f7f5", 24)

    amber = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    amber_draw = ImageDraw.Draw(amber)
    amber_draw.ellipse((760, 90, 1880, 760), fill=(255, 185, 92, 255))
    amber_draw.ellipse((1120, 180, 2080, 980), fill=(255, 137, 70, 170))
    amber_draw.ellipse((460, 180, 1100, 920), fill=(255, 227, 173, 135))
    amber = amber.filter(ImageFilter.GaussianBlur(70))
    screen = Image.alpha_composite(screen, amber)

    pale = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    pale_draw = ImageDraw.Draw(pale)
    pale_draw.ellipse((870, 210, 1640, 840), fill=(255, 255, 255, 175))
    pale_draw.ellipse((1320, 260, 1770, 760), fill=(255, 238, 205, 160))
    pale = pale.filter(ImageFilter.GaussianBlur(65))
    screen = Image.alpha_composite(screen, pale)
    canvas.alpha_composite(screen)

    ui = ImageDraw.Draw(canvas)
    mono = load_font(18, mono=True)
    sans_18 = load_font(18)
    sans_20 = load_font(20)
    sans_24 = load_font(24)
    sans_28 = load_font(28)
    sans_34 = load_font(34)

    text(ui, (inner[0] + 94, inner[1] + 14), "AiPaste", sans_24, "#20232b")
    text(ui, (inner[0] + 214, inner[1] + 16), "Prompt Library", sans_18, "#5b6170")
    text(ui, (inner[2] - 230, inner[1] + 16), "Mon 9:41", sans_18, "#616877")
    for idx in range(3):
        ui.ellipse((inner[0] + 30 + idx * 18, inner[1] + 58, inner[0] + 42 + idx * 18, inner[1] + 70), fill=["#ff5f57", "#febc2e", "#28c840"][idx])

    sidebar = (inner[0] + 24, inner[1] + 92, inner[0] + 290, inner[3] - 40)
    rounded_box(ui, sidebar, (255, 255, 255, 185), 28)
    text(ui, (sidebar[0] + 28, sidebar[1] + 30), "Clipboard Spaces", sans_24, "#1c2230")
    labels = [("All clips", True), ("Pinned prompts", False), ("Code context", False), ("Terminal", False), ("Research", False)]
    y = sidebar[1] + 90
    for label, active in labels:
        if active:
            rounded_box(ui, (sidebar[0] + 18, y - 6, sidebar[0] + 225, y + 32), "#ecf6f3", 18)
        text(ui, (sidebar[0] + 34, y), label, sans_18, "#213442" if active else "#586070")
        y += 60

    search_box = (sidebar[2] + 26, inner[1] + 96, inner[2] - 30, inner[1] + 156)
    rounded_box(ui, search_box, (255, 255, 255, 210), 24)
    text(ui, (search_box[0] + 26, search_box[1] + 17), "Search prompts, model outputs, commands...", sans_18, "#7d8592")

    panel = (sidebar[2] + 26, inner[1] + 182, inner[2] - 30, inner[3] - 56)
    rounded_box(ui, panel, (255, 255, 255, 210), 30)

    row_top = panel[1] + 118
    row_bottom = panel[1] + 390
    gap = 18
    widths = [186, 202, 186, 186, 224]
    starts = [panel[0] + 24]
    for width in widths[:-1]:
        starts.append(starts[-1] + width + gap)

    cards = [
        ((starts[0], row_top, starts[0] + widths[0], row_bottom), "#eef6ff", "#5d90f8", "PROMPT", "Rewrite this API error\nfor users.", "Claude"),
        ((starts[1], row_top, starts[1] + widths[1], row_bottom), "#fff3ea", "#ff8a55", "CONTEXT", "auth middleware\nrefresh path\nfailing stack trace", "Cursor"),
        ((starts[2], row_top, starts[2] + widths[2], row_bottom), "#edf8ef", "#4eb676", "OUTPUT", "Incident summary\nwith next actions", "ChatGPT"),
        ((starts[3], row_top, starts[3] + widths[3], row_bottom), "#fff8ea", "#e5b942", "TERMINAL", "./bin/aipaste list\n./bin/aipaste paste 1", "Terminal"),
        ((starts[4], row_top, starts[4] + widths[4], row_bottom), "#f4efff", "#8e67d8", "PINNED", "Launch checklist\nrelease note format\nreview rubric", "Library"),
    ]

    for box, fill, accent, overline, body, source in cards:
        rounded_box(ui, box, fill, 26)
        rounded_box(ui, (box[0] + 18, box[1] + 16, box[0] + 132, box[1] + 48), accent, 16)
        text(ui, (box[0] + 32, box[1] + 22), overline, mono, "#ffffff")
        source_bbox = ui.textbbox((0, 0), source, font=sans_18)
        text(ui, (box[2] - 18 - (source_bbox[2] - source_bbox[0]), box[1] + 22), source, sans_18, "#677083")
        multiline_block(ui, box[0] + 18, box[1] + 78, body.split("\n"), sans_20, "#18202c", 8)

    # Bottom chassis
    base_shadow = shadow_layer(canvas.size, (548, 904, 1834, 1032), radius=52, blur=36, color=(27, 34, 42, 55))
    canvas.alpha_composite(base_shadow)
    metal = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    metal_draw = ImageDraw.Draw(metal)
    metal_draw.rounded_rectangle((520, 900, 1866, 1012), radius=34, fill="#cfd3d9", outline="#aeb4bd", width=2)
    metal_draw.rounded_rectangle((1080, 966, 1308, 994), radius=14, fill="#b3b8c1")
    metal_draw.polygon([(520, 960), (410, 986), (1970, 986), (1866, 960)], fill="#bcc2ca")
    metal = metal.filter(ImageFilter.GaussianBlur(0.6))
    canvas.alpha_composite(metal)


def draw_floaters(canvas: Image.Image) -> None:
    draw = ImageDraw.Draw(canvas)
    sans_18 = load_font(18)
    sans_20 = load_font(20)
    sans_24 = load_font(24)
    mono = load_font(17, mono=True)

    for box, color, label, title, body in [
        ((120, 500, 438, 742), "#53c77f", "PASTE BACK", "Paste the right answer back into your editor.", "Keep the active app in flow while you reuse clips."),
        ((1820, 438, 2225, 690), "#6a93ff", "PROMPT OPS", "./bin/aipaste list --search release", "Manage reusable prompt and command fragments from CLI."),
    ]:
        canvas.alpha_composite(shadow_layer(canvas.size, (box[0] + 8, box[1] + 12, box[2] + 8, box[3] + 12), radius=32, blur=28, color=(19, 26, 36, 42)))
        rounded_box(draw, box, (255, 255, 255, 238), 30, outline=(18, 27, 38, 20), width=1)
        rounded_box(draw, (box[0] + 18, box[1] + 18, box[0] + 148, box[1] + 52), color, 16)
        text(draw, (box[0] + 32, box[1] + 24), label, mono, "#ffffff")
        text(draw, (box[0] + 24, box[1] + 84), title, sans_24, "#18212e")
        multiline_block(draw, box[0] + 24, box[1] + 126, body.split("\n"), sans_18, "#5f6877", 8)

    bubble = (236, 292, 576, 444)
    canvas.alpha_composite(shadow_layer(canvas.size, (330, 300, 648, 438), radius=28, blur=26, color=(19, 26, 36, 40)))
    rounded_box(draw, bubble, (255, 255, 255, 244), 28)
    rounded_box(draw, (bubble[0] + 18, bubble[1] + 18, bubble[0] + 114, bubble[1] + 52), "#93a7ff", 16)
    text(draw, (bubble[0] + 34, bubble[1] + 24), "SEARCH", mono, "#ffffff")
    text(draw, (bubble[0] + 20, bubble[1] + 84), "Find the exact prompt\nthat produced the good answer.", sans_24, "#1d2430")


def add_icon(canvas: Image.Image) -> None:
    if not ICON_PATH.exists():
        return
    icon = Image.open(ICON_PATH).convert("RGBA").resize((56, 56))
    canvas.alpha_composite(icon, (502, 188))


def write_philosophy() -> None:
    content = """# Soft Precision

Soft Precision treats productivity software as a calm instrument rather than a dashboard. Space should feel breathable, edges deliberate, and every surface meticulously crafted so the composition reads as a premium native Mac artifact rather than a generic SaaS mockup. The image must feel labored over with deep expertise, with transitions and alignments refined until the work appears inevitable.

Color should communicate usefulness without noise: warm light behind the device, cool paper-like surfaces for interface layers, and a few disciplined accents to identify prompt, context, output, and command states. The image should look painstakingly balanced, as if every highlight and shadow was tuned by hand to preserve clarity while still feeling aspirational.

Scale is the main storytelling tool. The laptop is the anchor because AiPaste is a macOS product; surrounding elements should support the central promise of capturing, retrieving, and reusing AI workflow fragments. Floating cards act like evidence rather than decoration, arranged with master-level restraint so they suggest activity without clutter.

Typography should be sparse and functional. Labels are present only where they help sell the product behavior: prompt, context, output, paste back, command search. The final result should look meticulously crafted, patient, and premium, with enough polish to stand beside a high-end software launch while remaining unmistakably specific to AiPaste.
"""
    PHILOSOPHY_PATH.write_text(content, encoding="utf-8")


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    write_philosophy()
    canvas = create_background()
    draw_macbook(canvas)
    draw_floaters(canvas)
    add_icon(canvas)
    canvas.convert("RGB").save(OUTPUT, quality=95)
    print(f"wrote {OUTPUT}")


if __name__ == "__main__":
    main()
