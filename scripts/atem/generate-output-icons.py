#!/usr/bin/env python3
"""Generate Stream Deck icons for ATEM output toggle (Program vs Multiview)."""

import os

from PIL import Image, ImageDraw, ImageFont

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "icons") + os.sep
SIZE = 144
CORNER_RADIUS = 20


def rounded_rect(draw, xy, radius, fill):
    draw.rounded_rectangle(xy, radius=radius, fill=fill)


def create_multiview_icon():
    """Multiview active — 4-quadrant grid icon, blue."""
    img = Image.new('RGB', (SIZE, SIZE), '#1565C0')
    draw = ImageDraw.Draw(img)
    rounded_rect(draw, [0, 0, SIZE, SIZE], CORNER_RADIUS, '#1565C0')

    # Draw 4 quadrant screens
    gap = 6
    pad = 24
    quad_w = (SIZE - pad * 2 - gap) // 2
    quad_h = (60 - gap) // 2

    top = 30
    for row in range(2):
        for col in range(2):
            x = pad + col * (quad_w + gap)
            y = top + row * (quad_h + gap)
            color = '#90CAF9' if not (row == 0 and col == 0) else '#FFFFFF'
            draw.rectangle([x, y, x + quad_w, y + quad_h], fill=color, outline='#BBDEFB', width=1)

    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 11)
    except Exception:
        font = ImageFont.load_default()

    text = "MULTIVIEW"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_x = (SIZE - (bbox[2] - bbox[0])) // 2
    draw.text((text_x, SIZE - 22), text, fill='#FFFFFF', font=font)

    img.save(OUTPUT_DIR + "atem-multiview-active.png")
    print("Created: atem-multiview-active.png")


def create_program_icon():
    """Program output active — single full screen icon, red."""
    img = Image.new('RGB', (SIZE, SIZE), '#C62828')
    draw = ImageDraw.Draw(img)
    rounded_rect(draw, [0, 0, SIZE, SIZE], CORNER_RADIUS, '#C62828')

    # Single full monitor
    pad = 28
    mon_top = 32
    mon_h = 55
    draw.rectangle([pad, mon_top, SIZE - pad, mon_top + mon_h], fill='#FFFFFF', outline='#EF9A9A', width=2)

    # "PGM" text inside monitor
    try:
        font_sm = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 16)
    except Exception:
        font_sm = ImageFont.load_default()

    pgm = "PGM"
    bbox = draw.textbbox((0, 0), pgm, font=font_sm)
    px = (SIZE - (bbox[2] - bbox[0])) // 2
    py = mon_top + (mon_h - (bbox[3] - bbox[1])) // 2
    draw.text((px, py), pgm, fill='#C62828', font=font_sm)

    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 11)
    except Exception:
        font = ImageFont.load_default()

    text = "PROGRAM"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_x = (SIZE - (bbox[2] - bbox[0])) // 2
    draw.text((text_x, SIZE - 22), text, fill='#FFFFFF', font=font)

    img.save(OUTPUT_DIR + "atem-program-active.png")
    print("Created: atem-program-active.png")


def create_inactive_icons():
    """Inactive/dim versions of both."""
    for name, label in [('multiview', 'MULTIVIEW'), ('program', 'PROGRAM')]:
        img = Image.new('RGB', (SIZE, SIZE), '#2a2a2a')
        draw = ImageDraw.Draw(img)
        rounded_rect(draw, [0, 0, SIZE, SIZE], CORNER_RADIUS, '#2a2a2a')

        if name == 'multiview':
            gap = 6
            pad = 24
            quad_w = (SIZE - pad * 2 - gap) // 2
            quad_h = (60 - gap) // 2
            top = 30
            for row in range(2):
                for col in range(2):
                    x = pad + col * (quad_w + gap)
                    y = top + row * (quad_h + gap)
                    draw.rectangle([x, y, x + quad_w, y + quad_h], fill='#444444', outline='#555555', width=1)
        else:
            pad = 28
            mon_top = 32
            mon_h = 55
            draw.rectangle([pad, mon_top, SIZE - pad, mon_top + mon_h], fill='#444444', outline='#555555', width=1)
            try:
                font_sm = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 16)
            except Exception:
                font_sm = ImageFont.load_default()
            pgm = "PGM"
            bbox = draw.textbbox((0, 0), pgm, font=font_sm)
            px = (SIZE - (bbox[2] - bbox[0])) // 2
            py = mon_top + (mon_h - (bbox[3] - bbox[1])) // 2
            draw.text((px, py), pgm, fill='#555555', font=font_sm)

        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 11)
        except Exception:
            font = ImageFont.load_default()

        bbox = draw.textbbox((0, 0), label, font=font)
        text_x = (SIZE - (bbox[2] - bbox[0])) // 2
        draw.text((text_x, SIZE - 22), label, fill='#666666', font=font)

        img.save(OUTPUT_DIR + f"atem-{name}-inactive.png")
        print(f"Created: atem-{name}-inactive.png")


if __name__ == "__main__":
    create_multiview_icon()
    create_program_icon()
    create_inactive_icons()
    print("\nAll ATEM output icons generated!")
