"""A clean iPhone (Pro Max style) frame around a screenshot, rendered at any width, optionally rotated, with glow."""
from PIL import Image, ImageDraw, ImageFilter


def rounded_mask(size, radius, scale=3):
    w, h = size
    big = Image.new("L", (w * scale, h * scale), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, w * scale - 1, h * scale - 1), radius=radius * scale, fill=255)
    return big.resize((w, h), Image.LANCZOS)


def phone(screenshot, width=1000, island=True):
    """Returns an RGBA image of an iPhone showing `screenshot` (PIL image), `width` px wide (device frame)."""
    shot = screenshot.convert("RGB")
    bezel = int(width * 0.028)
    edge = int(width * 0.012)
    screen_w = width - 2 * (bezel + edge)
    screen_h = int(screen_w * shot.height / shot.width)
    height = screen_h + 2 * (bezel + edge)
    outer_r = int(width * 0.16)
    screen_r = int(screen_w * 0.125)
    img = Image.new("RGBA", (width + 12, height), (0, 0, 0, 0))
    # side buttons (left: action + volume, right: power), drawn first so the frame overlaps them
    d = ImageDraw.Draw(img)
    btn = (70, 70, 78, 255)
    def button(x, y, w, h):
        d.rounded_rectangle((x, y, x + w, y + h), radius=w // 2, fill=btn)
    bw = max(4, int(width * 0.012))
    button(0, int(height * 0.17), bw + 6, int(height * 0.045))
    button(0, int(height * 0.25), bw + 6, int(height * 0.075))
    button(0, int(height * 0.34), bw + 6, int(height * 0.075))
    button(width + 6 - bw, int(height * 0.27), bw + 6, int(height * 0.11))
    frame = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    # titanium frame: dark gradient with a light rim
    metal = Image.new("RGBA", (width, height))
    md = ImageDraw.Draw(metal)
    for y in range(height):
        t = y / height
        c = int(78 - 30 * t)
        md.line([(0, y), (width, y)], fill=(c, c, c + 6, 255))
    frame.paste(metal, (0, 0), rounded_mask((width, height), outer_r))
    rim = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle((1, 1, width - 2, height - 2), radius=outer_r, outline=(170, 170, 182, 255), width=max(2, edge // 3))
    frame.alpha_composite(rim)
    # black bezel
    inner = Image.new("RGBA", (width - 2 * edge, height - 2 * edge), (6, 6, 8, 255))
    frame.paste(inner, (edge, edge), rounded_mask(inner.size, outer_r - edge))
    # screen
    screen = shot.resize((screen_w, screen_h), Image.LANCZOS).convert("RGBA")
    frame.paste(screen, (edge + bezel, edge + bezel), rounded_mask((screen_w, screen_h), screen_r))
    if island:
        iw, ih = int(screen_w * 0.29), int(screen_w * 0.085)
        ix = edge + bezel + (screen_w - iw) // 2
        iy = edge + bezel + int(screen_w * 0.028)
        ImageDraw.Draw(frame).rounded_rectangle((ix, iy, ix + iw, iy + ih), radius=ih // 2, fill=(0, 0, 0, 255))
    img.alpha_composite(frame, (6, 0))
    return img


def with_glow(device, color=(255, 170, 80), radius=60, strength=0.8, shadow=True):
    """Adds a soft colored glow (and a dark drop shadow) behind a device image."""
    pad = radius * 3
    w, h = device.size
    out = Image.new("RGBA", (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    alpha = device.getchannel("A")
    if shadow:
        sh = Image.new("RGBA", out.size, (4, 2, 20, 0))
        m = Image.new("L", out.size, 0)
        m.paste(alpha, (pad, pad + radius // 2))
        sh.putalpha(m.filter(ImageFilter.GaussianBlur(radius * 0.6)).point(lambda v: int(v * 0.65)))
        out.alpha_composite(sh)
    gl = Image.new("RGBA", out.size, color + (0,))
    m = Image.new("L", out.size, 0)
    m.paste(alpha, (pad, pad))
    gl.putalpha(m.filter(ImageFilter.GaussianBlur(radius)).point(lambda v: int(min(255, v * strength))))
    out.alpha_composite(gl)
    out.alpha_composite(device, (pad, pad))
    return out, pad


def rotated(image, degrees):
    return image.rotate(degrees, resample=Image.BICUBIC, expand=True)
