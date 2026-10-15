"""Cheat revealer badges: assets/reveal/<key>.png (64 x 64) and the base64 block of server.js (GET /reveal/<key>.png).

assets/reveal/src/<key>.png is the picture of the software (the owners' MIT licensed "p2c-icons" set, any size; aw has none, it is
drawn here as a plain monogram). This script puts each one on a dark glass tile (rim light, glow in the picture's own colour,
shadow, specular) and writes the result, then embeds all of them into server.js (the license server's Docker image has no assets
folder). To change a picture: replace its file in assets/reveal/src/ and run `python3 tools/make_reveal_icons.py`.
"""
import base64
import colorsys
import os
import re

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "reveal")
SRC = os.path.join(OUT, "src")
KEYS = ["gs", "prim", "nix", "nl", "ot", "fat", "aw", "pan", "ev"]
FALLBACK = {"aw": ("AW", (190, 30, 30), (255, 255, 255))}   # a picture we do not have: letters on a coloured square
FONTS = ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "DejaVuSans-Bold.ttf"]
R, M, SIZE = 512, 34, 64   # work canvas, margin for the outer glow, final size


def fallback(key):
    letters, bg, fg = FALLBACK[key]
    img = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, 511, 511), radius=128, fill=bg + (255,))
    font = None
    for path in FONTS:
        try:
            font = ImageFont.truetype(path, 240)
            break
        except OSError:
            pass
    font = font or ImageFont.load_default()
    box = d.textbbox((0, 0), letters, font=font)
    d.text(((512 - (box[2] - box[0])) / 2 - box[0], (512 - (box[3] - box[1])) / 2 - box[1]), letters, font=font, fill=fg + (255,))
    return img


def accent(img):
    """the most saturated bright colour of the picture (the colour of the glow and the rim)"""
    small = np.asarray(img.convert("RGBA").resize((32, 32)))
    best, best_score = None, 0.0
    for r, g, b, a in small.reshape(-1, 4):
        if a > 200:
            _, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s * v > best_score:
                best, best_score = (int(r), int(g), int(b)), s * v
    if best is None or best_score < 0.25:
        return (200, 205, 225)
    h, s, _ = colorsys.rgb_to_hsv(*(c / 255 for c in best))
    return tuple(int(c * 255) for c in colorsys.hsv_to_rgb(h, s, 1))


def rr_mask(box, radius):
    m = Image.new("L", (R, R), 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius=radius, fill=255)
    return m


def linear(c1, c2, angle=90, a1=255, a2=255):
    ys, xs = np.mgrid[0:R, 0:R].astype(float) / (R - 1)
    th = np.deg2rad(angle)
    t = np.clip((xs * np.cos(th) + ys * np.sin(th) - min(0, np.cos(th), np.sin(th), np.cos(th) + np.sin(th)))
                / (abs(np.cos(th)) + abs(np.sin(th))), 0, 1)
    arr = np.zeros((R, R, 4), dtype=np.uint8)
    for i in range(3):
        arr[..., i] = (c1[i] * (1 - t) + c2[i] * t).astype(np.uint8)
    arr[..., 3] = (a1 * (1 - t) + a2 * t).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def radial(center, radius, color, peak):
    ys, xs = np.mgrid[0:R, 0:R].astype(float)
    d = np.sqrt((xs - center[0]) ** 2 + (ys - center[1]) ** 2) / radius
    arr = np.zeros((R, R, 4), dtype=np.uint8)
    arr[..., 0], arr[..., 1], arr[..., 2] = color
    arr[..., 3] = (np.clip(1 - d, 0, 1) ** 1.6 * peak).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def clip(img, mask):
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), ImageChops.multiply(mask, img.split()[3]))
    return out


def tint(color, k, base):
    return tuple(int(base[i] * (1 - k) + color[i] * k) for i in range(3))


def badge(picture):
    ac = accent(picture)
    box, radius = (M, M, R - M, R - M), 104
    mask = rr_mask(box, radius)
    body = clip(linear(tint(ac, .20, (34, 36, 50)), tint(ac, .06, (10, 10, 16)), 90), mask)
    out = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    glow = Image.new("RGBA", (R, R), ac + (0,))
    glow.putalpha(rr_mask(box, radius).filter(ImageFilter.GaussianBlur(24)).point(lambda v: int(v * .55)))
    out = Image.alpha_composite(Image.alpha_composite(out, glow), body)
    out = Image.alpha_composite(out, clip(radial((R / 2, R * .52), R * .40, ac, 110), mask))
    out = Image.alpha_composite(out, clip(radial((R / 2, R * 1.02), R * .62, ac, 120), mask))
    n = int(R * .56)
    layer = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    layer.alpha_composite(picture.convert("RGBA").resize((n, n), Image.LANCZOS), ((R - n) // 2, (R - n) // 2 - 4))
    shadow = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    shadow.putalpha(layer.split()[3].point(lambda v: int(v * .75)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    moved = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    moved.alpha_composite(shadow, (0, 14))
    halo = Image.new("RGBA", (R, R), ac + (0,))
    halo.putalpha(layer.split()[3].filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(12)).point(lambda v: int(v * .6)))
    out = Image.alpha_composite(out, clip(moved, mask))
    out = Image.alpha_composite(out, clip(halo, mask))
    out = Image.alpha_composite(out, layer)
    spec = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    ImageDraw.Draw(spec).rounded_rectangle((M + 10, M + 8, R - M - 10, R * .47), radius=radius - 12, fill=(255, 255, 255, 46))
    spec = spec.filter(ImageFilter.GaussianBlur(2))
    fade = linear((255, 255, 255), (255, 255, 255), 90, 255, 0)
    out = Image.alpha_composite(out, clip(ImageChops.multiply(spec, fade), mask))
    ring = Image.new("L", (R, R), 0)
    ImageDraw.Draw(ring).rounded_rectangle(box, radius=radius, outline=255, width=7)
    out = Image.alpha_composite(out, clip(linear((255, 255, 255), ac, 45, 235, 235), ring))
    inner = Image.new("L", (R, R), 0)
    ImageDraw.Draw(inner).rounded_rectangle((M + 7, M + 7, R - M - 7, R - M - 7), radius=radius - 7, outline=255, width=3)
    out = Image.alpha_composite(out, clip(Image.new("RGBA", (R, R), (0, 0, 0, 110)), inner))
    return out.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    os.makedirs(SRC, exist_ok=True)
    rows = []
    for key in KEYS:
        path = os.path.join(SRC, key + ".png")
        picture = Image.open(path).convert("RGBA") if os.path.exists(path) else fallback(key)
        result = badge(picture)
        result.save(os.path.join(OUT, key + ".png"), optimize=True)
        with open(os.path.join(OUT, key + ".png"), "rb") as f:
            rows.append("    %s: Buffer.from('%s', 'base64')," % (key, base64.b64encode(f.read()).decode()))
    block = "const REVEAL_PNG = {\n" + "\n".join(rows) + "\n}\n"
    path = os.path.join(ROOT, "server.js")
    js = open(path, encoding="utf-8").read()
    if "const REVEAL_PNG" not in js:
        raise SystemExit("server.js has no REVEAL_PNG block yet")
    open(path, "w", encoding="utf-8").write(re.sub(r"const REVEAL_PNG = \{.*?\n\}\n", lambda m: block, js, flags=re.S))


if __name__ == "__main__":
    main()
