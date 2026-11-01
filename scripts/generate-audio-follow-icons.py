#!/usr/bin/env python3
"""Generate Stream Deck icons for the audio-follow toggle (speaker + TV)."""
import os

from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "icons")
SIZE, R = 144, 20


def make(active):
    bg, fg, accent = ("#2E7D32", "#FFFFFF", "#A5D6A7") if active else ("#37474F", "#90A4AE", "#546E7A")
    img = Image.new("RGB", (SIZE, SIZE), bg)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, SIZE, SIZE], radius=R, fill=bg)
    # TV
    d.rounded_rectangle([22, 28, 122, 86], radius=6, outline=fg, width=5)
    d.rectangle([60, 90, 84, 96], fill=fg)
    # speaker + sound waves inside the screen
    d.polygon([(44, 52), (54, 52), (66, 42), (66, 72), (54, 62), (44, 62)], fill=accent)
    for i, w in enumerate((8, 16)):
        d.arc([66 - w + 8, 57 - w - 2, 66 + w + 8, 57 + w + 2], -50, 50, fill=accent, width=3)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 15)
    except OSError:
        font = ImageFont.load_default()
    d.text((SIZE // 2, 118), "AUDIO", fill=fg, font=font, anchor="mm")
    name = "audio-follow-active.png" if active else "audio-follow-inactive.png"
    img.save(os.path.join(OUT, name))
    print("wrote", name)


make(True)
make(False)
