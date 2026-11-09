"""Composes Unhook's App Store screenshots (1320 x 2868) in the style of Bruce Run's set.

python3 compose.py <raw screenshot dir> <out dir> [--quick]
The raw dir holds full-size app screenshots from the CI UI tests (names like 01-today.jpg).
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from panorama import render_panorama
from ornaments import laurel_badge as wreath, line_icon, ribbons
from phone import phone, rotated, with_glow
from typo import halo, stack, subline, text_block, trim

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 1320, 2868
# Bruce's photo from the Bruce Run press kit (used with his permission) and two cut-out masks made with rembg.
PHOTO = os.path.join(HERE, "assets", "bruce-photo.jpg")
MASK = os.path.join(HERE, "assets", "bruce-mask-detailed.png")
HUMAN = os.path.join(HERE, "assets", "bruce-mask-body.png")
# Screen corners of the phone Bruce is holding in the photo (TL, TR, BR, BL), measured by hand.
SCREEN_QUAD = np.float32([[365, 1546], [887, 1568], [853, 2702], [333, 2694]])


def load_raw(raw_dir, name):
    for ext in (".png", ".jpg"):
        path = os.path.join(raw_dir, name + ext)
        if os.path.exists(path):
            return Image.open(path).convert("RGB")
    raise FileNotFoundError(name)


def headline(line1, line2, sub, width=1200, size=176, sub_size=60, top_style="white", bottom_style="dawn"):
    """Two tight lines of heavy type (white, then dawn gold) and a white subline, with a soft dark halo behind."""
    blocks = [trim(text_block(line1, size, top_style, max_width=width), margin=4)]
    if line2:
        blocks.append(trim(text_block(line2, size, bottom_style, max_width=width), margin=4))
    lines = stack(blocks, spacing=-int(size * 0.02))
    if sub:
        s = trim(subline(sub, sub_size, max_width=width), margin=4)
        lines = stack([lines, s], spacing=int(sub_size * 0.45))
    return lines


def place_headline(canvas, title, top):
    """Composites a headline centered at `top` with its halo; returns the y just below it."""
    shaded, pad = halo(title, radius=44, strength=0.42)
    canvas.alpha_composite(shaded, ((W - shaded.width) // 2, top - pad))
    return top + title.height


def screen_with_island(shot):
    """The app screenshot with rounded corners and a Dynamic Island, ready to be warped into a photo."""
    s = shot.resize((1320, 2868), Image.LANCZOS).convert("RGBA")
    d = ImageDraw.Draw(s)
    iw, ih = int(1320 * 0.29), int(1320 * 0.085)
    ix, iy = (1320 - iw) // 2, int(1320 * 0.028)
    d.rounded_rectangle((ix, iy, ix + iw, iy + ih), radius=ih // 2, fill=(0, 0, 0, 255))
    mask = Image.new("L", s.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 1319, 2867), radius=int(1320 * 0.125), fill=255)
    s.putalpha(mask)
    return s


def bruce_cutout(app_screen):
    """Bruce cut out of his Bruce Run photo, holding his phone with Unhook on it. Returns (RGBA image, mask)."""
    photo = cv2.imread(PHOTO)
    mask = np.maximum(cv2.imread(MASK, 0), cv2.imread(HUMAN, 0))
    # Above the chin use the detailed mask only (cleaner hair edges); below it add the body.
    detailed = cv2.imread(MASK, 0)
    mask[:1480] = detailed[:1480]
    blend = np.clip((np.arange(1480, 1560) - 1480) / 80.0, 0, 1)[:, None]
    mask[1480:1560] = (detailed[1480:1560] * (1 - blend) + mask[1480:1560] * blend).astype(np.uint8)
    mask = cv2.GaussianBlur(mask, (3, 3), 0)
    # Warm up the green glow the game threw around the phone.
    band = np.zeros(mask.shape, np.uint8)
    cv2.fillConvexPoly(band, SCREEN_QUAD.astype(np.int32), 255)
    band = cv2.dilate(band, np.ones((130, 130), np.uint8))
    hsv = cv2.cvtColor(photo, cv2.COLOR_BGR2HSV)
    hue = hsv[..., 0]
    # The game's green and magenta neon on the frame and fingers becomes Unhook's amber.
    neon = (((hue > 35) & (hue < 95)) | ((hue > 120) & (hue < 176))) & (band > 0) & (hsv[..., 1] > 40)
    hsv[..., 0] = np.where(neon, 16, hue)
    hsv[..., 1] = np.where(neon, (hsv[..., 1] * 0.7).astype(np.uint8), hsv[..., 1])
    photo = cv2.cvtColor(hsv, cv2.COLOR_HSV2BGR)
    # Warp the Unhook screen onto the phone.
    screen = screen_with_island(app_screen)
    src = np.float32([[0, 0], [1319, 0], [1319, 2867], [0, 2867]])
    matrix = cv2.getPerspectiveTransform(src, SCREEN_QUAD)
    rgba = np.array(screen)
    warped = cv2.warpPerspective(cv2.cvtColor(rgba, cv2.COLOR_RGBA2BGRA), matrix, (photo.shape[1], photo.shape[0]),
                                 flags=cv2.INTER_CUBIC)
    alpha = warped[..., 3:4].astype(np.float32) / 255
    photo = (photo * (1 - alpha) + warped[..., :3] * alpha).astype(np.uint8)
    person = Image.fromarray(cv2.cvtColor(photo, cv2.COLOR_BGR2RGB)).convert("RGBA")
    person.putalpha(Image.fromarray(mask))
    return person, Image.fromarray(mask)


def founder_shot(bg, app_screen, line1, line2, sub):
    """Screenshot 1: Bruce holding his phone, now showing Unhook."""
    person, mask = bruce_cutout(app_screen)
    canvas = bg.copy().convert("RGBA")
    # A warm glow behind Bruce so he separates from the night sky.
    glow = Image.new("RGBA", (W, H), (255, 160, 80, 0))
    glow.putalpha(mask.filter(ImageFilter.GaussianBlur(70)).point(lambda v: int(v * 0.75)))
    canvas.alpha_composite(glow)
    canvas.alpha_composite(person)
    place_headline(canvas, headline(line1, line2, sub), 96)
    return canvas.convert("RGB")


def phone_shot(bg, app_screen, line1, line2, sub, angle=0, phone_width=1000, x=None, y=900, badge=None,
               badge_at=(40, 760), glow=(255, 160, 80), icon=None):
    canvas = bg.copy().convert("RGBA")
    device = phone(app_screen, width=phone_width)
    device, pad = with_glow(device, color=glow, radius=70, strength=0.7)
    if angle:
        device = rotated(device, angle)
    cx = W // 2 if x is None else x
    canvas.alpha_composite(device, (int(cx - device.width / 2), int(y - pad)))
    top = 120
    if icon is not None:
        mark = line_icon(icon, 132)
        canvas.alpha_composite(mark, ((W - mark.width) // 2, 40))
        top = 40 + mark.height - 40
    place_headline(canvas, headline(line1, line2, sub), top)
    if badge is not None:
        canvas.alpha_composite(badge, badge_at)
    return canvas.convert("RGB")


# The set, in order. The first is Bruce holding his phone; the rest are framed phones on one wide sky that turns from
# night to sunrise across the set. x and y place the phone (center x, top y) within its screenshot.
SHOTS = [
    dict(raw="01-today", lines=("QUIT ANYTHING.", "ONE DAY AT A TIME."), sub="Hi, I'm Bruce. I made Unhook to help you."),
    dict(raw="07-sos", lines=("BEAT ANY", "CRAVING."), sub="60 seconds of guided breathing.",
         x=800, y=880, angle=-8, badge=("NO ADS", ["NO ACCOUNT", "NO TRACKING"])),
    dict(raw="10-progress", lines=("LEVEL UP", "EVERY DAY."), sub="Daily missions, XP and 12 ranks.", x=610, y=900, angle=7),
    dict(raw="21-challenge", lines=("THE 30-DAY", "RESET."), sub="One small step a day.", x=660, y=980, angle=0,
         icon="calendar"),
    dict(raw="05-habit-detail-more", lines=("WATCH YOUR", "BODY HEAL."), sub="A recovery timeline for every habit.",
         x=690, y=980, angle=-6, icon="heart"),
    dict(raw="09-coach", lines=("PRIVATE", "BY DESIGN."), sub="A coach on your iPhone. No account, no tracking.",
         x=660, y=980, angle=0, icon="lock"),
    dict(raw="17-celebration", lines=("CELEBRATE", "EVERY WIN."), sub="Milestones from your first hour to five years.",
         x=640, y=900, angle=6),
    dict(raw="13-goals", lines=("SAVE FOR WHAT", "MATTERS."), sub="Turn the money you save into real goals.",
         x=680, y=900, angle=-5),
]
PHONE_WIDTH = 940


def orbit_arcs():
    """One gold orbit behind each phone; the wings cross into the neighbouring screenshots."""
    arcs = []
    for i, shot in enumerate(SHOTS):
        if "x" not in shot:
            continue
        cx, cy = i * W + shot["x"], shot["y"] + 420
        tilt = -14 if i % 2 else 12
        arcs.append((cx, cy, 930, 250, tilt + shot["angle"] * 0.5, 110, 430, 1.25))
        arcs.append((cx + 40, cy + 520, 860, 200, -tilt * 0.6, 150, 400, 0.7))
    return arcs


def main(raw_dir, out_dir, quick=False):
    os.makedirs(out_dir, exist_ok=True)
    n = len(SHOTS)
    cache = os.path.join(HERE, ".cache", "pano-%d-%s.png" % (n, "quick" if quick else "full"))
    os.makedirs(os.path.dirname(cache), exist_ok=True)
    if os.path.exists(cache):
        pano = cv2.imread(cache)
    else:
        pano = render_panorama(shots=n, scale_down=2 if quick else 1)
        pano = cv2.resize(pano, (W * n, H))
        cv2.imwrite(cache, pano)
    pano = ribbons(pano, orbit_arcs(), np.random.default_rng(5))
    pano = Image.fromarray(cv2.cvtColor(pano, cv2.COLOR_BGR2RGB))
    for i, shot in enumerate(SHOTS):
        bg = pano.crop((i * W, 0, (i + 1) * W, H))
        line1, line2 = shot["lines"]
        if "x" not in shot:
            img = founder_shot(bg, load_raw(raw_dir, shot["raw"]), line1, line2, shot["sub"])
        else:
            badge = wreath(shot["badge"][0], shot["badge"][1], size=330) if "badge" in shot else None
            img = phone_shot(bg, load_raw(raw_dir, shot["raw"]), line1, line2, shot["sub"], angle=shot["angle"],
                             x=shot["x"], y=shot["y"], phone_width=PHONE_WIDTH, badge=badge, badge_at=(10, 700),
                             icon=shot.get("icon"))
        img.save(os.path.join(out_dir, f"{i + 1:02d}.png"))
    print("wrote", n, "screenshots to", out_dir)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], quick="--quick" in sys.argv)
