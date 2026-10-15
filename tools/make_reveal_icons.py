"""Cheat revealer badges: assets/reveal/<key>.png (32 x 32) and the base64 block of server.js (GET /reveal/<key>.png).

They are our own monogram badges (letters on a rounded square in the colour people connect with the software), NOT the logos of
those programs. To use real logos put a PNG (any size) with the same name into assets/reveal/ and run this script again: it draws
only the missing PNGs and always writes all of them into server.js (the license server's Docker image has no assets folder).
Usage: python3 tools/make_reveal_icons.py
"""
import base64
import os
import re

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "reveal")
# key: (letters, background, text)
BADGES = {
    "gs": ("GS", (22, 22, 22), (167, 214, 22)),
    "prim": ("PR", (88, 44, 160), (255, 255, 255)),
    "nix": ("NX", (0, 150, 190), (255, 255, 255)),
    "nl": ("NL", (0, 110, 235), (255, 255, 255)),
    "ot": ("OT", (255, 140, 0), (30, 30, 30)),
    "fat": ("FT", (225, 40, 105), (255, 255, 255)),
    "aw": ("AW", (190, 30, 30), (255, 255, 255)),
    "pan": ("PD", (140, 90, 220), (255, 255, 255)),
}
FONTS = ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "DejaVuSans-Bold.ttf"]


def draw(key):
    letters, bg, fg = BADGES[key]
    scale = 8
    img = Image.new("RGBA", (32 * scale, 32 * scale), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, 32 * scale - 1, 32 * scale - 1), radius=8 * scale, fill=bg + (255,))
    font = None
    for path in FONTS:
        try:
            font = ImageFont.truetype(path, 15 * scale)
            break
        except OSError:
            pass
    font = font or ImageFont.load_default()
    box = d.textbbox((0, 0), letters, font=font)
    d.text(((32 * scale - (box[2] - box[0])) / 2 - box[0], (32 * scale - (box[3] - box[1])) / 2 - box[1]), letters, font=font, fill=fg + (255,))
    return img.resize((32, 32), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    for key in BADGES:
        path = os.path.join(OUT, key + ".png")
        if not os.path.exists(path):
            draw(key).save(path, optimize=True)
        else:
            # a logo put here by hand can be any size: it is scaled down (aspect kept, centred, transparent padding) to 32 x 32
            img = Image.open(path).convert("RGBA")
            if img.size != (32, 32):
                img.thumbnail((32, 32), Image.LANCZOS)
                canvas = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
                canvas.paste(img, ((32 - img.width) // 2, (32 - img.height) // 2), img)
                canvas.save(path, optimize=True)
    rows = []
    for key in BADGES:
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
