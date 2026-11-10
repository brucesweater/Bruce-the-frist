"""A preview of how Unhook's listing looks in App Store search results (dark mode): icon, name, subtitle, Get
button and the first three screenshots. For checking the set, not for upload.

python3 search_preview.py <final screenshots dir> <app icon png> <out.png>
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

FONTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fonts")
NAME = "Unhook: Quit Bad Habits"
SUBTITLE = "Stop Smoking, Vaping, Drinking"


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.width - 1, img.height - 1), radius=radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def main(shots_dir, icon_path, out):
    scale = 3  # points to pixels, like a 3x iPhone
    W = 440 * scale
    pad = 20 * scale
    shot_w = (W - 2 * pad - 2 * 8 * scale) // 3
    shot_h = int(shot_w * 2868 / 1320)
    H = pad + 64 * scale + 14 * scale + shot_h + pad
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)
    icon = Image.open(icon_path).convert("RGBA").resize((64 * scale, 64 * scale), Image.LANCZOS)
    img.alpha_composite(rounded(icon, int(64 * scale * 0.2237)), (pad, pad))
    name_font = ImageFont.truetype(os.path.join(FONTS, "Nunito-Bold.ttf"), 17 * scale)
    sub_font = ImageFont.truetype(os.path.join(FONTS, "Nunito-Bold.ttf"), 13 * scale)
    tx = pad + 64 * scale + 12 * scale
    d.text((tx, pad + 10 * scale), NAME, font=name_font, fill=(255, 255, 255))
    d.text((tx, pad + 34 * scale), SUBTITLE, font=sub_font, fill=(142, 142, 147))
    bw, bh = 74 * scale, 30 * scale
    bx, by = W - pad - bw, pad + 17 * scale
    d.rounded_rectangle((bx, by, bx + bw, by + bh), radius=bh // 2, fill=(44, 44, 46))
    get_font = ImageFont.truetype(os.path.join(FONTS, "Nunito-Black.ttf"), 15 * scale)
    gw = d.textlength("Get", font=get_font)
    d.text((bx + (bw - gw) / 2, by + 4 * scale), "Get", font=get_font, fill=(10, 132, 255))
    y = pad + 64 * scale + 14 * scale
    for k in range(3):
        shot = Image.open(os.path.join(shots_dir, f"{k + 1:02d}.png")).convert("RGB").resize((shot_w, shot_h), Image.LANCZOS)
        img.alpha_composite(rounded(shot, 12 * scale), (pad + k * (shot_w + 8 * scale), y))
    img.convert("RGB").save(out)
    print("wrote", out)


if __name__ == "__main__":
    main(*sys.argv[1:4])
