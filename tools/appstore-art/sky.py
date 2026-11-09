"""Painterly night-to-dawn sky for Unhook's App Store art (original artwork, generated procedurally).

Brush strokes follow a swirling flow field (curl of fractal noise plus vortices around big stars), colored from a
palette that moves from deep night on the left to dawn on the right, so a panorama sliced into screenshots tells a
"night turns into day" story. Usage: python3 sky.py <width> <height> <out.png> [seed] [dawn_start 0..1] [dawn_end]
"""
import math
import sys

import cv2
import numpy as np


def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def fbm(h, w, rng, octaves=5, base=6):
    """Fractal value noise in [0, 1]."""
    total = np.zeros((h, w), np.float32)
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        cells = base * (2 ** o)
        grid = rng.random((max(2, int(cells * h / max(h, w))) + 1, cells + 1)).astype(np.float32)
        layer = cv2.resize(grid, (w, h), interpolation=cv2.INTER_CUBIC)
        total += amp * layer
        norm += amp
        amp *= 0.5
    total /= norm
    total = (total - total.min()) / (total.max() - total.min() + 1e-6)
    return total


def lerp(a, b, t):
    return a + (b - a) * t[..., None]


def palette_field(w, h, dawn_start, dawn_end, variation):
    """Base color per pixel (float RGB 0..255)."""
    y = np.linspace(0, 1, h, dtype=np.float32)[:, None] * np.ones((1, w), np.float32)
    x = np.linspace(0, 1, w, dtype=np.float32)[None, :] * np.ones((h, 1), np.float32)
    top = np.array([12, 16, 58], np.float32)
    mid = np.array([30, 38, 120], np.float32)
    low = np.array([70, 44, 150], np.float32)
    night = np.where((y < 0.55)[..., None], lerp(top, mid, y / 0.55), lerp(mid, low, (y - 0.55) / 0.45))
    # Dawn: warm light rising from the bottom, stronger toward the right of the panorama.
    dawn_amount = smoothstep(dawn_start, dawn_end, x) * smoothstep(0.35, 1.0, y)
    rose = np.array([232, 92, 140], np.float32)
    amber = np.array([255, 170, 80], np.float32)
    warm = lerp(rose, amber, smoothstep(0.6, 1.0, y))
    color = lerp(night, warm, dawn_amount * 0.9)
    # Painterly variation: lighter and darker patches.
    color = color * (0.78 + 0.44 * variation[..., None])
    return np.clip(color, 0, 255)


def flow_angles(h, w, rng, vortices):
    n = fbm(h, w, rng, octaves=4, base=3)
    n = cv2.GaussianBlur(n, (0, 0), sigmaX=max(w, h) / 90)
    gy, gx = np.gradient(n)
    angle = np.arctan2(gy, gx) + math.pi / 2  # curl: follow the noise's contour lines
    # Mostly horizontal drift, like wind across the sky.
    angle = np.arctan2(np.sin(angle) * 0.55, np.cos(angle) + 0.9)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    for cx, cy, radius, direction in vortices:
        dx, dy = xx - cx, yy - cy
        dist = np.sqrt(dx * dx + dy * dy) + 1e-3
        tangent = np.arctan2(dy, dx) + direction * math.pi / 2
        weight = np.exp(-((dist / (radius * 1.8)) ** 2))
        angle = np.arctan2(
            np.sin(angle) * (1 - weight) + np.sin(tangent) * weight,
            np.cos(angle) * (1 - weight) + np.cos(tangent) * weight,
        )
    return angle.astype(np.float32)


def paint_strokes(canvas, color_field, angle, rng, count, length, width, steps, jitter):
    h, w = angle.shape
    xs = rng.uniform(0, w, count).astype(np.float32)
    ys = rng.uniform(0, h, count).astype(np.float32)
    pts = np.zeros((count, steps, 2), np.float32)
    px, py = xs.copy(), ys.copy()
    step = length / steps
    for k in range(steps):
        pts[:, k, 0], pts[:, k, 1] = px, py
        ix = np.clip(px.astype(np.int32), 0, w - 1)
        iy = np.clip(py.astype(np.int32), 0, h - 1)
        a = angle[iy, ix]
        px = px + np.cos(a) * step
        py = py + np.sin(a) * step
    ix = np.clip(xs.astype(np.int32), 0, w - 1)
    iy = np.clip(ys.astype(np.int32), 0, h - 1)
    base = color_field[iy, ix]
    shade = rng.normal(1.0, jitter, (count, 1)).astype(np.float32)
    tint = rng.normal(0, 14, (count, 3)).astype(np.float32)
    colors = np.clip(base * shade + tint, 0, 255).astype(np.int32)
    widths = np.maximum(1, rng.normal(width, width * 0.25, count)).astype(np.int32)
    for i in range(count):
        c = colors[i]
        cv2.polylines(canvas, [pts[i].astype(np.int32)], False, (int(c[2]), int(c[1]), int(c[0])),
                      int(widths[i]), cv2.LINE_AA)


def swirl_star(canvas, glow, cx, cy, radius, rng, warm=1.0):
    """A big Van Gogh-like star: bright core with rings of short gold and blue dashes."""
    gold = (94, 201, 246)      # BGR
    pale = (150, 236, 255)
    blue = (255, 182, 143)
    rings = int(radius / 9)
    for r in range(rings):
        rr = radius * (0.25 + 0.75 * r / max(1, rings - 1))
        dashes = int(10 + rr / 6)
        for d in range(dashes):
            start = (d / dashes) * 360 + rng.uniform(-6, 6)
            span = 360 / dashes * rng.uniform(0.45, 0.8)
            pick = rng.random()
            color = pale if r < rings * 0.35 else (gold if pick < 0.55 * warm + 0.2 else blue)
            thickness = max(2, int(radius / 26 * rng.uniform(0.7, 1.3)))
            cv2.ellipse(canvas, (int(cx), int(cy)), (int(rr), int(rr)), 0, start, start + span, color,
                        thickness, cv2.LINE_AA)
    cv2.circle(canvas, (int(cx), int(cy)), int(radius * 0.22), (120, 230, 255), -1, cv2.LINE_AA)
    cv2.circle(glow, (int(cx), int(cy)), int(radius * 1.1), (60, 170, 255), -1, cv2.LINE_AA)


def small_stars(canvas, glow, rng, count, h, w):
    for _ in range(count):
        x, y = int(rng.uniform(0, w)), int(rng.uniform(0, h * 0.8))
        r = max(1, int(rng.uniform(1, 3.2) * w / 1980))
        cv2.circle(canvas, (x, y), r, (190, 240, 255), -1, cv2.LINE_AA)
        cv2.circle(glow, (x, y), r * 5, (80, 190, 255), -1, cv2.LINE_AA)


def render(width, height, seed=7, dawn_start=0.45, dawn_end=1.0, stars=None):
    rng = np.random.default_rng(seed)
    scale = width / 7920
    variation = fbm(height, width, rng, octaves=5, base=10)
    color_field = palette_field(width, height, dawn_start, dawn_end, variation)
    if stars is None:
        stars = []
        for i in range(6):
            cx = (i + rng.uniform(0.2, 0.8)) * width / 6
            cy = rng.uniform(0.06, 0.32) * height
            stars.append((cx, cy, rng.uniform(150, 260) * scale))
    vortices = [(cx, cy, r, 1 if i % 2 else -1) for i, (cx, cy, r) in enumerate(stars)]
    angle = flow_angles(height, width, rng, vortices)
    canvas = cv2.cvtColor(color_field.astype(np.uint8), cv2.COLOR_RGB2BGR)
    canvas = cv2.GaussianBlur(canvas, (0, 0), 6 * scale + 1)
    area = width * height / (7920 * 2868)
    paint_strokes(canvas, color_field, angle, rng, int(70000 * area), 120 * scale, 16 * scale, 9, 0.18)
    paint_strokes(canvas, color_field, angle, rng, int(140000 * area), 70 * scale, 9 * scale, 7, 0.24)
    paint_strokes(canvas, color_field * 1.12, angle, rng, int(90000 * area), 40 * scale, 5 * scale, 5, 0.3)
    glow = np.zeros_like(canvas)
    for cx, cy, r in stars:
        swirl_star(canvas, glow, cx, cy, r, rng)
    small_stars(canvas, glow, rng, int(260 * width / 7920), height, width)
    glow = cv2.GaussianBlur(glow, (0, 0), 40 * scale + 2)
    out = cv2.add(canvas, (glow * 0.55).astype(np.uint8))
    return out


if __name__ == "__main__":
    w, h, path = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
    seed = int(sys.argv[4]) if len(sys.argv) > 4 else 7
    ds = float(sys.argv[5]) if len(sys.argv) > 5 else 0.45
    de = float(sys.argv[6]) if len(sys.argv) > 6 else 1.0
    img = render(w, h, seed, ds, de)
    cv2.imwrite(path, img)
    print("wrote", path, img.shape)
