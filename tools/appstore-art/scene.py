"""Painterly Unhook scenes (original procedural artwork): swirling night-to-dawn sky, rising sun, hills, glowing path.

Functions return BGR uint8 images (OpenCV). Everything is seeded, so renders are reproducible.
"""
import math

import cv2
import numpy as np

from sky import fbm, smoothstep, swirl_star


def lerp3(a, b, t):
    return np.array(a, np.float32) + (np.array(b, np.float32) - np.array(a, np.float32)) * t


def sky_colors(h, w, sun_x, sun_y, warmth, rng):
    """RGB float field: night at the top, violet in the middle, warm dawn around the sun and the horizon."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    y = yy / h
    top = np.array([10, 14, 52], np.float32)
    mid = np.array([38, 40, 128], np.float32)
    low = np.array([96, 52, 150], np.float32)
    t1 = np.clip(y / 0.5, 0, 1)[..., None]
    t2 = np.clip((y - 0.5) / 0.5, 0, 1)[..., None]
    base = np.where((y < 0.5)[..., None], top + (mid - top) * t1, mid + (low - mid) * t2)
    d = np.sqrt(((xx - sun_x) / w) ** 2 * 1.4 + ((yy - sun_y) / h) ** 2) + 1e-6
    glow = np.clip(1 - d / 0.75, 0, 1) ** 1.6 * warmth
    rose = np.array([236, 96, 140], np.float32)
    amber = np.array([255, 176, 82], np.float32)
    sun_core = np.array([255, 226, 150], np.float32)
    warm = rose + (amber - rose) * np.clip(1 - d / 0.35, 0, 1)[..., None]
    warm = warm + (sun_core - warm) * (np.clip(1 - d / 0.14, 0, 1) ** 1.5)[..., None]
    color = base + (warm - base) * glow[..., None]
    variation = fbm(h, w, rng, octaves=5, base=9)
    color *= (0.82 + 0.36 * variation)[..., None]
    return np.clip(color, 0, 255)


def flow_field(h, w, rng, vortices, sun=None):
    n = fbm(h, w, rng, octaves=3, base=3)
    n = cv2.GaussianBlur(n, (0, 0), sigmaX=max(w, h) / 70)
    gy, gx = np.gradient(n)
    angle = np.arctan2(gy, gx) + math.pi / 2
    angle = np.arctan2(np.sin(angle) * 0.6, np.cos(angle) + 1.1)  # mostly horizontal drift
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    for cx, cy, radius, direction in vortices:
        dx, dy = xx - cx, yy - cy
        dist = np.sqrt(dx * dx + dy * dy) + 1e-3
        tangent = np.arctan2(dy, dx) + direction * math.pi / 2
        weight = np.exp(-((dist / (radius * 2.2)) ** 2))
        angle = np.arctan2(np.sin(angle) * (1 - weight) + np.sin(tangent) * weight,
                           np.cos(angle) * (1 - weight) + np.cos(tangent) * weight)
    if sun is not None:  # rays: strokes around the sun bend into concentric arcs
        sx, sy, sr = sun
        dx, dy = xx - sx, yy - sy
        dist = np.sqrt(dx * dx + dy * dy) + 1e-3
        tangent = np.arctan2(dy, dx) + math.pi / 2
        weight = np.exp(-((dist / (sr * 3.2)) ** 2)) * 0.85
        angle = np.arctan2(np.sin(angle) * (1 - weight) + np.sin(tangent) * weight,
                           np.cos(angle) * (1 - weight) + np.cos(tangent) * weight)
    return angle.astype(np.float32)


def strokes(canvas, colors_rgb, angle, rng, count, length, width, steps, jitter, mask=None, accents=1.0):
    h, w = angle.shape
    xs = rng.uniform(0, w, count).astype(np.float32)
    ys = rng.uniform(0, h, count).astype(np.float32)
    if mask is not None:
        keep = mask[np.clip(ys.astype(int), 0, h - 1), np.clip(xs.astype(int), 0, w - 1)] > 0
        xs, ys = xs[keep], ys[keep]
        count = len(xs)
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
    base = colors_rgb[iy, ix]
    shade = rng.normal(1.0, jitter, (count, 1)).astype(np.float32)
    # Painterly accents: a few strokes pick up pale blue or gold, like the brush caught another color.
    accent = rng.random(count)
    colors = base * shade
    blue = accent < 0.018 * accents
    gold = accent > 1 - 0.01 * accents
    colors[blue] = colors[blue] * 0.55 + np.array([150, 190, 255], np.float32) * 0.45
    colors[gold] = colors[gold] * 0.45 + np.array([255, 210, 120], np.float32) * 0.55
    colors = np.clip(colors, 0, 255).astype(np.int32)
    widths = np.maximum(1, rng.normal(width, width * 0.22, count)).astype(np.int32)
    for i in range(count):
        c = colors[i]
        cv2.polylines(canvas, [pts[i].astype(np.int32)], False, (int(c[2]), int(c[1]), int(c[0])), int(widths[i]), cv2.LINE_AA)


def hills(h, w, rng, horizon, layers=3):
    """Returns a list of (mask, color_rgb) from far to near."""
    out = []
    x = np.arange(w, dtype=np.float32)
    for i in range(layers):
        freq = (rng.uniform(1.5, 3.5) + i) * min(1.0, w / h)  # fewer bumps on narrow images
        phase = rng.uniform(0, 6.28)
        amp = (0.035 + 0.025 * i) * h
        base_y = horizon + i * 0.045 * h
        noise = cv2.resize(rng.random((1, 8 + i * 4)).astype(np.float32), (w, 1), interpolation=cv2.INTER_CUBIC)[0]
        ys = base_y - amp * (0.55 * np.sin(x / w * freq * 6.28 + phase) + 0.45 * (noise - 0.5) * 2)
        mask = np.zeros((h, w), np.uint8)
        pts = np.concatenate([np.stack([x, ys], 1), [[w, h], [0, h]]]).astype(np.int32)
        cv2.fillPoly(mask, [pts], 255)
        color = lerp3([46, 30, 96], [14, 10, 34], i / max(1, layers - 1))
        out.append((mask, color))
    return out


def glow_disc(img, cx, cy, radius, color_bgr, strength):
    layer = np.zeros_like(img, np.float32)
    cv2.circle(layer, (int(cx), int(cy)), int(radius), color_bgr, -1, cv2.LINE_AA)
    layer = cv2.GaussianBlur(layer, (0, 0), radius * 0.6 + 1)
    return np.clip(img.astype(np.float32) + layer * strength, 0, 255).astype(np.uint8)


def render_scene(w, h, seed=3, sun=(0.5, 0.62, 0.11), warmth=1.0, stars_n=4, hills_on=True, path=True,
                 horizon=0.66, star_positions=None):
    rng = np.random.default_rng(seed)
    scale = math.sqrt(w * h / (1920 * 1080))
    sx, sy, sr = sun[0] * w, sun[1] * h, sun[2] * min(w, h)
    colors = sky_colors(h, w, sx, sy, warmth, rng)
    if star_positions is None:
        star_positions = [(rng.uniform(0.08, 0.92) * w, rng.uniform(0.08, 0.32) * h, rng.uniform(55, 95) * scale)
                          for _ in range(stars_n)]
    vortices = [(x, y, r, 1 if i % 2 else -1) for i, (x, y, r) in enumerate(star_positions)]
    angle = flow_field(h, w, rng, vortices, sun=(sx, sy, sr))
    canvas = cv2.cvtColor(colors.astype(np.uint8), cv2.COLOR_RGB2BGR)
    canvas = cv2.GaussianBlur(canvas, (0, 0), 5 * scale + 1)
    area = w * h / (1920 * 1080)
    strokes(canvas, colors, angle, rng, int(26000 * area), 70 * scale, 11 * scale, 10, 0.12)
    strokes(canvas, colors, angle, rng, int(42000 * area), 46 * scale, 7 * scale, 8, 0.16)
    strokes(canvas, np.clip(colors * 1.1, 0, 255), angle, rng, int(26000 * area), 26 * scale, 4 * scale, 6, 0.2)
    glow = np.zeros_like(canvas)
    for x, y, r in star_positions:
        swirl_star(canvas, glow, x, y, r, rng)
    for _ in range(int(90 * area)):
        x, y = rng.uniform(0, w), rng.uniform(0, h * horizon * 0.85)
        rr = max(1, int(rng.uniform(1.2, 2.8) * scale))
        cv2.circle(canvas, (int(x), int(y)), rr, (210, 240, 255), -1, cv2.LINE_AA)
        cv2.circle(glow, (int(x), int(y)), rr * 5, (90, 190, 255), -1, cv2.LINE_AA)
    glow = cv2.GaussianBlur(glow, (0, 0), 26 * scale + 2)
    canvas = cv2.add(canvas, (glow * 0.5).astype(np.uint8))
    # The sun: a bright disc with a soft halo, half behind the hills.
    canvas = glow_disc(canvas, sx, sy, sr * 3.0, (110, 170, 255), 0.55)
    canvas = glow_disc(canvas, sx, sy, sr * 1.6, (150, 215, 255), 0.7)
    cv2.circle(canvas, (int(sx), int(sy)), int(sr), (170, 235, 255), -1, cv2.LINE_AA)
    cv2.circle(canvas, (int(sx), int(sy)), int(sr * 0.82), (205, 245, 255), -1, cv2.LINE_AA)
    if hills_on:
        for i, (mask, color) in enumerate(hills(h, w, rng, horizon * h)):
            layer = np.zeros_like(canvas)
            layer[:] = (int(color[2]), int(color[1]), int(color[0]))
            # painterly texture on the hills too
            hill_colors = np.zeros((h, w, 3), np.float32)
            hill_colors[:] = color
            hill_angle = np.full_like(angle, 0.0) + cv2.GaussianBlur((mask.astype(np.float32) / 255), (0, 0), 25 * scale) * 0.0
            strokes(layer, hill_colors * 1.15, hill_angle, rng, int(9000 * area), 46 * scale, 7 * scale, 5, 0.08, mask, accents=0.0)
            m = (mask > 0)[..., None]
            canvas = np.where(m, layer, canvas)
            # warm rim light on the hill tops facing the sun
            edge = cv2.Canny(mask, 50, 150)
            edge = cv2.dilate(edge, np.ones((2, 2), np.uint8))
            rim = np.zeros_like(canvas, np.float32)
            rim[edge > 0] = (90, 170, 255)
            rim = cv2.GaussianBlur(rim, (0, 0), 3 * scale + 1) * (0.9 - 0.25 * i)
            canvas = np.clip(canvas.astype(np.float32) + rim, 0, 255).astype(np.uint8)
    if path:
        canvas = glowing_path(canvas, w, h, sx, sy + sr * 0.2, scale)
    return canvas


def glowing_path(canvas, w, h, tx, ty, scale, steps=30):
    """30 glowing stepping stones winding from the bottom to the sun: one per day of the reset."""
    pts = []
    for i in range(steps):
        t = i / (steps - 1)
        # Ease toward the horizon (perspective): steps get closer and smaller near the sun.
        e = 1 - (1 - t) ** 1.8
        x = w * 0.5 + math.sin(t * 5.2) * w * 0.16 * (1 - e) + (tx - w * 0.5) * e
        y = h * 1.02 + (ty - h * 1.02) * e
        pts.append((x, y, (1 - e) * 1.0 + 0.12))
    glow = np.zeros_like(canvas, np.float32)
    for x, y, s in pts:
        rx, ry = 34 * s * scale, 12 * s * scale
        cv2.ellipse(glow, (int(x), int(y)), (int(rx * 2.2), int(ry * 2.2)), 0, 0, 360, (90, 180, 255), -1, cv2.LINE_AA)
    glow = cv2.GaussianBlur(glow, (0, 0), 14 * scale)
    out = np.clip(canvas.astype(np.float32) + glow * 0.9, 0, 255).astype(np.uint8)
    for x, y, s in pts:
        rx, ry = 30 * s * scale, 10 * s * scale
        cv2.ellipse(out, (int(x), int(y)), (int(rx), int(ry)), 0, 0, 360, (150, 225, 255), -1, cv2.LINE_AA)
        cv2.ellipse(out, (int(x), int(y - ry * 0.25)), (int(rx * 0.7), int(ry * 0.5)), 0, 0, 360, (215, 248, 255), -1, cv2.LINE_AA)
    return out


if __name__ == "__main__":
    import sys
    w, h, out = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
    img = render_scene(w, h)
    cv2.imwrite(out, img)
    print("wrote", out)
