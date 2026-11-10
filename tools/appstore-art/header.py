"""The 3840 x 1646 header for Unhook's press kit and website, in the style of Bruce Run's header.

python3 header.py <raw screenshot dir> <out.jpg> [--quick]
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageFilter

from compose import bruce_cutout, load_raw
from ornaments import ribbons
from scene import render_scene
from typo import halo, stack, subline, text_block, trim

HW, HH = 3840, 1646


def main(raw_dir, out, quick=False):
    div = 2 if quick else 1
    sky = render_scene(HW // div, HH // div, seed=11, sun=(0.86, 0.80, 0.075), warmth=1.0, horizon=0.8,
                       star_positions=[(0.06 * HW / div, 0.16 * HH / div, 120 / div), (0.36 * HW / div, 0.1 * HH / div, 90 / div),
                                       (0.63 * HW / div, 0.13 * HH / div, 110 / div), (0.93 * HW / div, 0.2 * HH / div, 95 / div)],
                       path=True)
    sky = cv2.resize(sky, (HW, HH))
    # Two gold orbits sweeping behind Bruce.
    sky = ribbons(sky, [(2200, 980, 1150, 260, -9, 120, 420, 1.2), (2150, 1220, 1300, 230, 7, 160, 390, 0.75)],
                  np.random.default_rng(3))
    canvas = Image.fromarray(cv2.cvtColor(sky, cv2.COLOR_BGR2RGB)).convert("RGBA")

    # Bruce, from the top of his hair to below the phone, standing a little right of center.
    person, mask = bruce_cutout(load_raw(raw_dir, "30-onboarding-welcome"))
    top, bottom = 520, 2868
    person = person.crop((0, top, person.width, bottom))
    mask = mask.crop((0, top, mask.width, bottom))
    scale = (HH * 1.02) / person.height
    size = (int(person.width * scale), int(person.height * scale))
    person, mask = person.resize(size, Image.LANCZOS), mask.resize(size, Image.LANCZOS)
    x = int(HW * 0.585 - size[0] / 2)
    y = HH - size[1] + 30
    glow = Image.new("RGBA", canvas.size, (255, 160, 80, 0))
    gm = Image.new("L", canvas.size, 0)
    gm.paste(mask, (x, y))
    glow.putalpha(gm.filter(ImageFilter.GaussianBlur(90)).point(lambda v: int(v * 0.8)))
    canvas.alpha_composite(glow)
    canvas.alpha_composite(person, (x, y))

    # The wordmark, left of Bruce: UNHOOK in white over a gold tagline.
    word = trim(text_block("UNHOOK", 400, "white"), margin=6)
    tag = trim(text_block("QUIT ANYTHING.", 190, "dawn", max_width=word.width), margin=6)
    sub = trim(subline("One day at a time.", 92, color=(255, 255, 255)), margin=4)
    logo = stack([word, tag], spacing=-8)
    logo = stack([logo, sub], spacing=36)
    shaded, pad = halo(logo, radius=60, strength=0.45)
    cx = int(HW * 0.255)
    canvas.alpha_composite(shaded, (cx - shaded.width // 2, int(HH * 0.47 - shaded.height / 2)))
    canvas.convert("RGB").save(out, quality=94)
    print("wrote", out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], quick="--quick" in sys.argv)
