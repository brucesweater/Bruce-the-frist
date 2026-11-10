"""Gold ribbons, a laurel badge and small line icons for the App Store art (original artwork)."""
import math

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from typo import SUB, font, subline, text_block, trim, stack


def ribbons(bgr, arcs, rng):
    """Adds glowing gold orbit arcs to a BGR image in place-safe fashion and returns the result.

    Each arc is (cx, cy, rx, ry, tilt_degrees, start_degrees, end_degrees, strength). Angles follow image
    coordinates (y down), so 90 degrees is the front (bottom) of the orbit; the front glows brighter.
    """
    h, w = bgr.shape[:2]
    core = np.zeros((h, w), np.float32)
    thin = np.zeros((h, w), np.float32)
    glow = np.zeros((h, w), np.float32)
    sparkle = np.zeros((h, w), np.float32)
    for cx, cy, rx, ry, tilt, t0, t1, strength in arcs:
        ts = np.radians(np.linspace(t0, t1, 1400))
        ct, st = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))
        xs = cx + rx * np.cos(ts) * ct - ry * np.sin(ts) * st
        ys = cy + rx * np.cos(ts) * st + ry * np.sin(ts) * ct
        n = len(ts)
        for k in range(n - 1):
            u = k / (n - 1)
            fade = (math.sin(math.pi * u) ** 0.7) * (0.6 + 0.4 * math.sin(ts[k])) * strength
            p1, p2 = (int(xs[k]), int(ys[k])), (int(xs[k + 1]), int(ys[k + 1]))
            width = max(4, int(24 * (0.45 + 0.55 * math.sin(math.pi * u))))
            cv2.line(core, p1, p2, float(min(1.0, fade)), width, cv2.LINE_AA)
            cv2.line(thin, p1, p2, float(min(1.0, fade)), max(2, width // 3), cv2.LINE_AA)
            cv2.line(glow, p1, p2, float(fade), 70, cv2.LINE_AA)
        for _ in range(10):
            k = int(rng.uniform(0.12, 0.88) * (n - 1))
            u = k / (n - 1)
            fade = (math.sin(math.pi * u) ** 0.7) * strength
            cv2.circle(sparkle, (int(xs[k]), int(ys[k])), int(rng.uniform(5, 9)), float(min(1.0, fade)), -1, cv2.LINE_AA)
    glow = cv2.GaussianBlur(glow, (0, 0), 28)
    core = cv2.GaussianBlur(core, (0, 0), 1.4)
    halo = cv2.GaussianBlur(sparkle, (0, 0), 16)
    out = bgr.astype(np.float32)
    out += glow[..., None] * np.array([30, 120, 255], np.float32) * 0.75  # warm orange light around the ribbon
    out += halo[..., None] * np.array([60, 160, 255], np.float32) * 1.6

    def over(img, alpha, color):
        a = np.clip(alpha, 0, 1)[..., None]
        return img * (1 - a) + np.array(color, np.float32) * a

    out = over(out, core, (70, 190, 255))      # gold body (BGR)
    out = over(out, thin * 0.85, (175, 235, 255))  # pale center line
    out = over(out, sparkle, (220, 248, 255))
    return np.clip(out, 0, 255).astype(np.uint8)


def _gold(size):
    col = Image.new("RGB", (1, 256))
    for y in range(256):
        t = y / 255
        col.putpixel((0, y), (255, int(228 - 70 * t), int(138 - 90 * t)))
    return col.resize(size, Image.BILINEAR).convert("RGBA")


def laurel_badge(big, small_lines, size=330):
    """A gold laurel wreath around a short claim, like Bruce Run's "20+ CITIES & WORLDS"."""
    S = size * 3
    mask = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(mask)
    cx, cy, r = S / 2, S / 2 + S * 0.03, S * 0.39
    for side in (-1, 1):
        stem = []
        for k in range(40):
            u = k / 39
            a = math.radians(100 + u * 125) if side < 0 else math.radians(80 - u * 125)
            stem.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        d.line(stem, fill=255, width=int(S * 0.012), joint="curve")
        n = 9
        for k in range(n):
            u = (k + 0.5) / n
            a = math.radians(100 + u * 125) if side < 0 else math.radians(80 - u * 125)
            px, py = cx + r * math.cos(a), cy + r * math.sin(a)
            tangent = a + (math.pi / 2 if side < 0 else -math.pi / 2)
            length = S * 0.12 * (1 - 0.38 * u)
            for splay in (-1, 1):
                direction = tangent + splay * math.radians(38) * (-side)
                lx = px + math.cos(direction) * length * 0.5
                ly = py + math.sin(direction) * length * 0.5
                leaf = Image.new("L", (int(length), int(length * 0.42)), 0)
                ImageDraw.Draw(leaf).ellipse((0, 0, leaf.width - 1, leaf.height - 1), fill=255)
                leaf = leaf.rotate(-math.degrees(direction), resample=Image.BICUBIC, expand=True)
                mask.paste(255, (int(lx - leaf.width / 2), int(ly - leaf.height / 2)), leaf)
    wreath = _gold((S, S))
    wreath.putalpha(mask)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (S, S), (20, 8, 40, 0))
    shadow.putalpha(mask.filter(ImageFilter.GaussianBlur(S * 0.012)).point(lambda v: int(v * 0.6)))
    img.alpha_composite(shadow, (0, int(S * 0.01)))
    img.alpha_composite(wreath)
    inner = int(S * 0.5)
    blocks = [trim(text_block(big, int(S * 0.17), "dawn", max_width=inner), margin=2)]
    for line in small_lines:
        blocks.append(trim(subline(line, int(S * 0.062), max_width=inner, color=(255, 214, 120)), margin=2))
    text = stack(blocks, spacing=int(S * 0.012))
    img.alpha_composite(text, ((S - text.width) // 2, int(cy - text.height / 2 - S * 0.02)))
    return img.resize((size, size), Image.LANCZOS)


def line_icon(kind, size=150, color=(255, 205, 100)):
    """A small rounded line icon in gold with a glow: 'calendar' (with a check) or 'heart' (with a pulse)."""
    S = size * 4
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    lw = int(S * 0.07)
    if kind == "calendar":
        d.rounded_rectangle((S * 0.14, S * 0.2, S * 0.86, S * 0.86), radius=int(S * 0.12), outline=255, width=lw)
        d.line((S * 0.14, S * 0.4, S * 0.86, S * 0.4), fill=255, width=lw)
        for x in (0.34, 0.66):
            d.line((S * x, S * 0.1, S * x, S * 0.28), fill=255, width=lw)
        d.line([(S * 0.35, S * 0.62), (S * 0.47, S * 0.73), (S * 0.67, S * 0.52)], fill=255, width=lw, joint="curve")
    elif kind == "heart":
        pts = []
        for k in range(200):
            t = math.pi * 2 * k / 199
            x = 16 * math.sin(t) ** 3
            y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
            pts.append((S / 2 + x * S * 0.024, S * 0.5 + y * S * 0.024))
        d.line(pts, fill=255, width=lw, joint="curve")
        d.line([(S * 0.22, S * 0.5), (S * 0.38, S * 0.5), (S * 0.45, S * 0.38), (S * 0.55, S * 0.64),
                (S * 0.62, S * 0.5), (S * 0.78, S * 0.5)], fill=255, width=int(lw * 0.8), joint="curve")
    elif kind == "lock":
        d.rounded_rectangle((S * 0.2, S * 0.44, S * 0.8, S * 0.88), radius=int(S * 0.1), outline=255, width=lw)
        d.arc((S * 0.3, S * 0.12, S * 0.7, S * 0.62), 180, 360, fill=255, width=lw)
        d.line((S * 0.3, S * 0.37, S * 0.3, S * 0.45), fill=255, width=lw)
        d.line((S * 0.7, S * 0.37, S * 0.7, S * 0.45), fill=255, width=lw)
        d.ellipse((S * 0.45, S * 0.58, S * 0.55, S * 0.68), fill=255)
    m = m.resize((size, size), Image.LANCZOS)
    pad = size // 3
    out = Image.new("RGBA", (size + pad * 2, size + pad * 2), (0, 0, 0, 0))
    glow_mask = Image.new("L", out.size, 0)
    glow_mask.paste(m, (pad, pad))
    glow = Image.new("RGBA", out.size, (255, 150, 60, 0))
    glow.putalpha(glow_mask.filter(ImageFilter.GaussianBlur(size * 0.09)).point(lambda v: int(min(255, v * 1.1))))
    out.alpha_composite(glow)
    face = Image.new("RGBA", (size, size), color + (0,))
    face.putalpha(m)
    out.alpha_composite(face, (pad, pad))
    return out
