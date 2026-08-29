#!/usr/bin/env python3
"""Generate wallpaper.png.

The wallpaper is committed as a binary, so this script exists to say where it
came from and to let it be regenerated at another resolution (the Xreal
glasses, say):

    python3 modules/niri/make-wallpaper.py 1920 1080 modules/niri/wallpaper.png

Colours are taken from the niri config in this directory: #7fc8ff is the
focus-ring accent, so the desktop and the compositor agree on a palette.
"""
import sys
from PIL import Image

W = int(sys.argv[1]) if len(sys.argv) > 1 else 1920
H = int(sys.argv[2]) if len(sys.argv) > 2 else 1080
OUT = sys.argv[3] if len(sys.argv) > 3 else "modules/niri/wallpaper.png"

TOP, BOTTOM = (0x12, 0x15, 0x1c), (0x06, 0x07, 0x0a)
GLOWS = [  # (cx, cy, radius, colour, strength) in fractions of the canvas
    (0.28, 0.30, 0.75, (0x7f, 0xc8, 0xff), 0.20),
    (0.82, 0.86, 0.60, (0x4a, 0x7f, 0xb5), 0.11),
]

img = Image.new("RGB", (W, H))
px = img.load()
diag = (W * W + H * H) ** 0.5

for y in range(H):
    t = y / (H - 1)
    base = [TOP[i] + (BOTTOM[i] - TOP[i]) * t for i in range(3)]
    for x in range(W):
        r, g, b = base
        for cx, cy, rad, col, strength in GLOWS:
            dx, dy = x - cx * W, y - cy * H
            d = (dx * dx + dy * dy) ** 0.5 / (rad * diag)
            if d < 1.0:
                # smoothstep falloff — no hard edge where the glow ends
                f = (1 - d) ** 2 * (3 - 2 * (1 - d)) * strength
                r += (col[0] - r) * f
                g += (col[1] - g) * f
                b += (col[2] - b) * f
        # Ordered dither. Without it an 8-bit gradient this shallow shows
        # visible banding across a 1080p panel.
        d4 = ((x & 1) ^ (y & 1)) * 0.5 + ((x >> 1 & 1) ^ (y >> 1 & 1)) * 0.25 - 0.375
        px[x, y] = (
            max(0, min(255, int(r + d4 + 0.5))),
            max(0, min(255, int(g + d4 + 0.5))),
            max(0, min(255, int(b + d4 + 0.5))),
        )

img.save(OUT, "PNG", optimize=True)
print(f"wrote {OUT} ({W}x{H})")
