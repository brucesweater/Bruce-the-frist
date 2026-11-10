"""Unhook's two creative assets for the App Store's Asset Library: the product page header and the search result.

python3 store_art.py header <raw screenshot dir> <out.png> [--quick] [--guide]
python3 store_art.py search <raw screenshot dir> <out.png> [--quick] [--guide]

The App Store crops these differently on each device, so every word stays inside the safe area of Apple's
templates. --guide draws that safe area in red, for checking only (don't upload a picture made with it).
"""
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from compose import bruce_cutout, load_raw
from ornaments import ribbons
from phone import phone, rotated, with_glow
from scene import render_scene
from typo import halo, stack, subline, text_block, trim

# Picture sizes and safe areas (left, top, right, bottom), measured from Apple's templates.
HEADER = dict(size=(3840, 1646), safe=(1097, 493, 2743, 1154))
SEARCH = dict(size=(3840, 2560), safe=(836, 765, 3004, 1795))


def sky(size, div, seed, sun, horizon, stars, arcs):
    w, h = size
    art = render_scene(w // div, h // div, seed=seed, sun=sun, warmth=1.0, horizon=horizon, path=True,
                       star_positions=[(x * w / div, y * h / div, r / div) for x, y, r in stars])
    art = cv2.resize(art, (w, h))
    art = ribbons(art, arcs, np.random.default_rng(3))
    return Image.fromarray(cv2.cvtColor(art, cv2.COLOR_BGR2RGB)).convert("RGBA")


def place_words(canvas, blocks, left, middle_y, radius=50):
    """Puts a stack of text lines with its dark halo at `left`, centered on `middle_y`. Returns the text's box."""
    shaded, pad = halo(blocks, radius=radius, strength=0.5)
    top = int(middle_y - blocks.height / 2)
    canvas.alpha_composite(shaded, (left - pad, top - pad))
    return left, top, left + blocks.width, top + blocks.height


def finish(canvas, kind, words_box, out, guide):
    left, top, right, bottom = kind["safe"]
    inside = words_box[0] >= left and words_box[1] >= top and words_box[2] <= right and words_box[3] <= bottom
    print("words at", words_box, "inside the safe area" if inside else "OUTSIDE the safe area")
    if guide:
        ImageDraw.Draw(canvas).rectangle(kind["safe"], outline=(255, 59, 48, 255), width=6)
    canvas.convert("RGB").save(out)
    print("wrote", out)
    return inside


def header(raw_dir, out, quick=False, guide=False):
    """Bruce holding his phone on the right of the safe area, the name and tagline on its left. He stands low
    enough that the iPhone's Dynamic Island, which sits over the top of the header, doesn't cover his hair."""
    w, h = HEADER["size"]
    left, top, right, bottom = HEADER["safe"]
    canvas = sky((w, h), 2 if quick else 1, seed=11, sun=(0.9, 0.82, 0.07), horizon=0.82,
                 stars=[(0.07, 0.17, 120), (0.3, 0.1, 90), (0.52, 0.14, 100), (0.93, 0.2, 95)],
                 arcs=[(2440, 980, 1150, 260, -9, 120, 420, 1.2), (2400, 1220, 1300, 230, 7, 160, 390, 0.75)])
    person, mask = bruce_cutout(load_raw(raw_dir, "30-onboarding-welcome"))
    person, mask = person.crop((0, 520, person.width, 2868)), mask.crop((0, 520, mask.width, 2868))
    scale = (h * 0.96) / person.height
    size = (int(person.width * scale), int(person.height * scale))
    person, mask = person.resize(size, Image.LANCZOS), mask.resize(size, Image.LANCZOS)
    x, y = int(2440 - size[0] / 2), 300
    glow = Image.new("RGBA", canvas.size, (255, 160, 80, 0))
    spread = Image.new("L", canvas.size, 0)
    spread.paste(mask, (x, y))
    glow.putalpha(spread.filter(ImageFilter.GaussianBlur(90)).point(lambda v: int(v * 0.8)))
    canvas.alpha_composite(glow)
    canvas.alpha_composite(person, (x, y))

    width = 800
    word = trim(text_block("UNHOOK", 400, "white", max_width=width), margin=4)
    tag = trim(text_block("QUIT ANYTHING.", 190, "dawn", max_width=word.width), margin=4)
    sub = trim(subline("One day at a time.", 62, color=(255, 255, 255)), margin=4)
    words = stack([stack([word, tag], spacing=-4), sub], spacing=30)
    box = place_words(canvas, words, left + 24, (top + bottom) / 2)
    return finish(canvas, HEADER, box, out, guide)


def search(raw_dir, out, quick=False, guide=False):
    """The Today screen on a tilted iPhone, with the tagline beside it."""
    w, h = SEARCH["size"]
    left, top, right, bottom = SEARCH["safe"]
    canvas = sky((w, h), 2 if quick else 1, seed=23, sun=(0.12, 0.8, 0.07), horizon=0.8,
                 stars=[(0.08, 0.13, 130), (0.33, 0.09, 100), (0.55, 0.16, 90), (0.92, 0.14, 125)],
                 arcs=[(2640, 1250, 1250, 330, -10, 130, 430, 1.25), (2600, 1640, 1350, 260, 8, 170, 400, 0.75)])
    device = phone(load_raw(raw_dir, "01-today"), width=1060)
    device, pad = with_glow(device, color=(255, 160, 80), radius=80, strength=0.7)
    device = rotated(device, -7)
    canvas.alpha_composite(device, (int(2640 - device.width / 2), int(h / 2 - device.height / 2)))

    # Three big lines, so the words can still be read on the small card in search results.
    width = 1130
    lines = [trim(text_block("QUIT", 400, "white", max_width=width), margin=4),
             trim(text_block("ANYTHING.", 400, "white", max_width=width), margin=4),
             trim(text_block("ONE DAY AT A TIME.", 400, "dawn", max_width=width), margin=4)]
    words = stack([stack(lines[:2], spacing=6, align="left"), lines[2]], spacing=40, align="left")
    box = place_words(canvas, words, left + 40, (top + bottom) / 2)
    return finish(canvas, SEARCH, box, out, guide)


if __name__ == "__main__":
    make = {"header": header, "search": search}[sys.argv[1]]
    ok = make(sys.argv[2], sys.argv[3], quick="--quick" in sys.argv, guide="--guide" in sys.argv)
    sys.exit(0 if ok else 1)
