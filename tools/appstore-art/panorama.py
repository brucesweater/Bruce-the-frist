"""One wide painted sky for the App Store screenshot set: deep night on the first screenshot, sunrise on the last."""
import math

import cv2
import numpy as np

from scene import flow_field, glow_disc, strokes
from sky import fbm, swirl_star


def panorama_colors(h, w, rng):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    x, y = xx / w, yy / h
    top = np.array([10, 13, 50], np.float32)
    mid = np.array([34, 36, 120], np.float32)
    low = np.array([78, 46, 146], np.float32)
    t1 = np.clip(y / 0.55, 0, 1)[..., None]
    t2 = np.clip((y - 0.55) / 0.45, 0, 1)[..., None]
    base = np.where((y < 0.55)[..., None], top + (mid - top) * t1, mid + (low - mid) * t2)
    # Dawn rises from the bottom, getting stronger toward the right end of the set.
    progress = np.clip((x - 0.04) / 0.96, 0, 1) ** 0.85
    rise = np.clip((y - (0.97 - 0.62 * progress)) / 0.42, 0, 1)
    warmth = (progress * 0.9 + 0.1) * rise
    rose = np.array([232, 92, 140], np.float32)
    amber = np.array([255, 172, 84], np.float32)
    warm = rose + (amber - rose) * np.clip((y - 0.6) / 0.4, 0, 1)[..., None]
    color = base + (warm - base) * warmth[..., None]
    variation = fbm(h, w, rng, octaves=5, base=24)
    color *= (0.8 + 0.4 * variation)[..., None]
    return np.clip(color, 0, 255)


def render_panorama(shots=6, shot_w=1320, shot_h=2868, seed=21, scale_down=1):
    w, h = shots * shot_w // scale_down, shot_h // scale_down
    s = 1.0 / scale_down * 1.25
    rng = np.random.default_rng(seed)
    colors = panorama_colors(h, w, rng)
    # Big swirling stars sit on the seams between screenshots (top corners and between the phones), so none lands
    # behind the middle of a headline, and a star cut by a seam continues on the next screenshot, like Bruce Run's set.
    stars = [(rng.uniform(0.04, 0.09) * w / shots, rng.uniform(0.03, 0.05) * h, 105 * s)]
    for i in range(1, shots):
        seam = i * w / shots
        stars.append((seam + rng.uniform(-0.06, 0.06) * w / shots, rng.uniform(0.02, 0.07) * h,
                      rng.uniform(85, 125) * s * (1.0 - 0.05 * i)))
        if i < shots - 1 and rng.random() < 0.7:
            stars.append((seam + rng.uniform(-0.12, 0.12) * w / shots, rng.uniform(0.31, 0.5) * h,
                          rng.uniform(58, 95) * s))
    sun = (w * 0.93, h * 0.97, 120 * s)
    vortices = [(x, y, r, 1 if k % 2 else -1) for k, (x, y, r) in enumerate(stars)]
    angle = flow_field(h, w, rng, vortices, sun=sun)
    canvas = cv2.cvtColor(colors.astype(np.uint8), cv2.COLOR_RGB2BGR)
    canvas = cv2.GaussianBlur(canvas, (0, 0), 6 * s + 1)
    area = (w * h) / (1920 * 1080)
    strokes(canvas, colors, angle, rng, int(24000 * area), 95 * s, 14 * s, 10, 0.12)
    strokes(canvas, colors, angle, rng, int(36000 * area), 62 * s, 9 * s, 8, 0.15)
    strokes(canvas, np.clip(colors * 1.1, 0, 255), angle, rng, int(22000 * area), 36 * s, 5 * s, 6, 0.18)
    glow = np.zeros_like(canvas)
    for x, y, r in stars:
        swirl_star(canvas, glow, x, y, r, rng)
    for _ in range(int(60 * area)):
        x, y = rng.uniform(0, w), rng.uniform(0, h * 0.7)
        rr = max(1, int(rng.uniform(1.4, 3.4) * s))
        cv2.circle(canvas, (int(x), int(y)), rr, (210, 240, 255), -1, cv2.LINE_AA)
        cv2.circle(glow, (int(x), int(y)), rr * 5, (90, 190, 255), -1, cv2.LINE_AA)
    glow = cv2.GaussianBlur(glow, (0, 0), 30 * s + 2)
    canvas = cv2.add(canvas, (glow * 0.5).astype(np.uint8))
    canvas = glow_disc(canvas, sun[0], sun[1], sun[2] * 4.5, (90, 160, 255), 0.6)
    canvas = glow_disc(canvas, sun[0], sun[1], sun[2] * 2.2, (140, 210, 255), 0.7)
    return canvas


if __name__ == "__main__":
    import sys
    out = sys.argv[1]
    down = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    img = render_panorama(scale_down=down)
    cv2.imwrite(out, img)
    print("wrote", out, img.shape)
