"""Bold two-tone headlines in the style of Bruce's App Store art: heavy rounded type, white line + dawn-gradient line,
a short 3D extrusion and a soft drop shadow. Returns RGBA PIL images.
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fonts")
HEAVY = os.path.join(FONTS, "Fredoka-Bold.ttf")
SUB = os.path.join(FONTS, "Nunito-Black.ttf")


def font(path, size):
    return ImageFont.truetype(path, size)


def gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    return img


def _fast_gradient(size, top, bottom):
    # vertical gradient via resize (fast)
    col = Image.new("RGB", (1, 256))
    for y in range(256):
        t = y / 255
        col.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return col.resize(size, Image.BILINEAR)


STYLES = {
    "white": {"top": (255, 255, 255), "bottom": (226, 232, 255), "extrude": (150, 150, 196)},
    "dawn": {"top": (255, 232, 120), "bottom": (255, 132, 40), "extrude": (176, 66, 18)},
    "rose": {"top": (255, 170, 190), "bottom": (255, 84, 132), "extrude": (150, 30, 70)},
}


def text_block(text, size, style="white", tracking=0, max_width=None, font_path=HEAVY):
    """One line of heavy text with extrusion and shadow, auto-shrunk to max_width."""
    f = font(font_path, size)
    while True:
        bbox = f.getbbox(text)
        width = bbox[2] - bbox[0] + tracking * max(0, len(text) - 1)
        if max_width is None or width <= max_width or size <= 20:
            break
        size = int(size * 0.95)
        f = font(font_path, size)
    pad = int(size * 0.35)
    ascent, descent = f.getmetrics()
    w, h = width + pad * 2, ascent + descent + pad * 2
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    x = pad - bbox[0]
    for ch in text:
        d.text((x, pad), ch, font=f, fill=255)
        x += f.getlength(ch) + tracking
    s = STYLES[style]
    depth = max(2, int(size * 0.055))
    out = Image.new("RGBA", (w, h + depth + int(size * 0.2)), (0, 0, 0, 0))
    # soft shadow
    shadow = Image.new("RGBA", out.size, (10, 6, 40, 0))
    shadow_mask = Image.new("L", out.size, 0)
    shadow_mask.paste(mask, (0, depth + int(size * 0.06)))
    shadow.putalpha(shadow_mask.filter(ImageFilter.GaussianBlur(size * 0.07)).point(lambda v: int(v * 0.7)))
    out.alpha_composite(shadow)
    # extrusion
    ext = Image.new("RGBA", out.size, s["extrude"] + (0,))
    ext_mask = Image.new("L", out.size, 0)
    for dy in range(1, depth + 1):
        ext_mask.paste(255, (0, dy), mask) if False else ext_mask.paste(Image.new("L", mask.size, 255), (0, dy), mask)
    ext.putalpha(ext_mask)
    out.alpha_composite(ext)
    # face
    face = _fast_gradient((w, h), s["top"], s["bottom"]).convert("RGBA")
    face.putalpha(mask)
    out.alpha_composite(face, (0, 0))
    # subtle top highlight inside the letters
    hl = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    hl_mask = mask.filter(ImageFilter.GaussianBlur(size * 0.02))
    hl_alpha = Image.new("L", (w, h), 0)
    hl_alpha.paste(hl_mask.crop((0, 0, w, int(h * 0.5))), (0, 0))
    hl.putalpha(hl_alpha.point(lambda v: int(v * 0.12)))
    out.alpha_composite(hl)
    return out


def subline(text, size, max_width=None, color=(255, 255, 255)):
    f = font(SUB, size)
    while max_width and f.getlength(text) > max_width and size > 16:
        size = int(size * 0.95)
        f = font(SUB, size)
    pad = int(size * 0.4)
    ascent, descent = f.getmetrics()
    w, h = int(f.getlength(text)) + pad * 2, ascent + descent + pad * 2
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text((pad, pad), text, font=f, fill=255)
    out = Image.new("RGBA", (w, h + int(size * 0.15)), (0, 0, 0, 0))
    shadow = Image.new("RGBA", out.size, (8, 6, 36, 0))
    sm = Image.new("L", out.size, 0)
    sm.paste(mask, (0, int(size * 0.08)))
    shadow.putalpha(sm.filter(ImageFilter.GaussianBlur(size * 0.12)).point(lambda v: int(v * 0.8)))
    out.alpha_composite(shadow)
    face = Image.new("RGBA", (w, h), color + (0,))
    face.putalpha(mask)
    out.alpha_composite(face)
    return out


def stack(blocks, spacing=0, align="center"):
    """Vertically stacks RGBA blocks (negative spacing overlaps lines slightly, like the reference art)."""
    width = max(b.width for b in blocks)
    height = sum(b.height for b in blocks) + spacing * (len(blocks) - 1)
    out = Image.new("RGBA", (width, max(1, height)), (0, 0, 0, 0))
    y = 0
    for b in blocks:
        x = (width - b.width) // 2 if align == "center" else 0
        out.alpha_composite(b, (x, max(0, y)))
        y += b.height + spacing
    return out


def trim(img, margin=0, threshold=6):
    """Crops an RGBA image to its visible pixels plus `margin`, so stacked lines sit as tight as the reference art."""
    alpha = img.getchannel("A").point(lambda v: 255 if v > threshold else 0)
    box = alpha.getbbox()
    if box is None:
        return img
    l, t, r, b = box
    return img.crop((max(0, l - margin), max(0, t - margin), min(img.width, r + margin), min(img.height, b + margin)))


def halo(img, radius=40, strength=0.45, color=(6, 4, 30)):
    """A wide, soft dark glow behind a block of text, so it reads over bright stars."""
    pad = radius * 2
    out = Image.new("RGBA", (img.width + pad * 2, img.height + pad * 2), (0, 0, 0, 0))
    m = Image.new("L", out.size, 0)
    m.paste(img.getchannel("A"), (pad, pad))
    shade = Image.new("RGBA", out.size, color + (0,))
    shade.putalpha(m.filter(ImageFilter.GaussianBlur(radius)).point(lambda v: int(min(255, v * strength * 2))))
    out.alpha_composite(shade)
    out.alpha_composite(img, (pad, pad))
    return out, pad
