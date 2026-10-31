#!/usr/bin/env python3
"""Generate abstract light/dark wallpapers with a known dominant hue (used to demo dynamic accent)."""
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "prototypes" / "assets" / "wallpapers"
W, H = 2400, 1500


def oklch_to_srgb(L, C, h):
    a = C * np.cos(np.radians(h))
    b = C * np.sin(np.radians(h))
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_**3, m_**3, s_**3
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    rgb = np.stack([r, g, bl], axis=-1)
    rgb = np.clip(rgb, 0, 1)
    return np.where(rgb <= 0.0031308, 12.92 * rgb, 1.055 * np.power(rgb, 1 / 2.4) - 0.055)


# id, accent hue, secondary hue, tertiary hue
SETS = [
    ("dune", 55, 25, 85),
    ("lagoon", 220, 185, 265),
    ("orchid", 320, 285, 15),
    ("moss", 150, 115, 195),
]


def field(seed, hues, dark):
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    x /= W
    y /= H
    L = np.full((H, W), 0.18 if dark else 0.95, np.float32)
    A = np.zeros((H, W), np.float32)
    B = np.zeros((H, W), np.float32)
    weight = np.full((H, W), 1e-3, np.float32)

    def add(cx, cy, r, hue, l, c, k=1.0):
        nonlocal L, A, B, weight
        d = ((x - cx) ** 2 + ((y - cy) * H / W) ** 2) / (r * r)
        w = np.exp(-d) * k
        A += w * c * math.cos(math.radians(hue))
        B += w * c * math.sin(math.radians(hue))
        L += w * (l - L) * 0.85
        weight += w

    # flowing ribbons
    for i in range(3):
        hue = hues[i % 3]
        phase = rng.uniform(0, math.tau)
        amp = rng.uniform(0.08, 0.18)
        base = 0.25 + i * 0.25
        thickness = rng.uniform(0.07, 0.13)
        centre = base + amp * np.sin(x * math.tau * rng.uniform(0.6, 1.1) + phase)
        w = np.exp(-(((y - centre) / thickness) ** 2)) * 0.9
        l_target = (0.42 + 0.08 * i) if dark else (0.80 - 0.07 * i)
        c = 0.14 if dark else 0.12
        A += w * c * math.cos(math.radians(hue))
        B += w * c * math.sin(math.radians(hue))
        L += w * (l_target - L) * 0.7
        weight += w
        # crisp highlight edge on the ribbon, gives glass something to refract
        edge = np.exp(-(((y - centre - thickness * 0.9) / 0.006) ** 2)) * 0.5
        L += edge * ((0.75 if dark else 1.0) - L)
    for _ in range(6):
        hue = hues[rng.integers(0, 3)]
        add(rng.uniform(0, 1), rng.uniform(0, 1), rng.uniform(0.15, 0.35), hue,
            rng.uniform(0.26, 0.4) if dark else rng.uniform(0.78, 0.92), 0.11 if dark else 0.08, 0.8)
    norm = np.maximum(weight, 1.0)
    A /= norm
    B /= norm

    # Defined shapes so blur over glass reads as glass, not as a flat tint.
    def blend(mask, hue, l, c):
        nonlocal L, A, B
        L += mask * (l - L)
        A += mask * (c * math.cos(math.radians(hue)) - A)
        B += mask * (c * math.sin(math.radians(hue)) - B)

    def circle(cx, cy, r, soft):
        d = np.sqrt((x - cx) ** 2 + ((y - cy) * H / W) ** 2)
        return np.clip((r - d) / soft + 0.5, 0, 1), d

    # large orbs with a lit upper edge
    for i in range(3):
        hue = hues[i % 3]
        cx, cy, r = rng.uniform(0.1, 0.9), rng.uniform(0.15, 0.85), rng.uniform(0.12, 0.22)
        m, d = circle(cx, cy, r, 0.004)
        shade = np.clip(0.5 - (y - cy) * H / W / r * 0.5 + (x - cx) / r * -0.2, 0, 1)
        l = (0.26 + 0.2 * shade) if dark else (0.68 + 0.26 * shade)
        blend(m * 0.7, hue, l, 0.14 if dark else 0.12)
        rim = np.exp(-(((d - r) / 0.0025) ** 2)) * np.clip(-(y - cy) / r, 0, 1)
        L += rim * 0.35 * ((0.8 if dark else 1.0) - L)
    # diagonal light streaks
    for _ in range(3):
        ang = math.radians(rng.uniform(-35, -20))
        off = rng.uniform(-0.2, 1.0)
        dist = (y - off) * math.cos(ang) - x * math.sin(ang) * W / H * 0.6
        w = rng.uniform(0.002, 0.008)
        s = np.exp(-((dist / w) ** 2)) * rng.uniform(0.12, 0.3)
        L += s * ((0.7 if dark else 1.0) - L)
    # bokeh
    for _ in range(12):
        hue = hues[rng.integers(0, 3)]
        r = rng.uniform(0.008, 0.03)
        m, _d = circle(rng.uniform(0, 1), rng.uniform(0, 1), r, r * 0.35)
        blend(m * rng.uniform(0.15, 0.35), hue, 0.62 if dark else 0.98, 0.12 if dark else 0.06)

    C = np.sqrt(A * A + B * B)
    h = np.degrees(np.arctan2(B, A))
    # vignette for dark
    if dark:
        L *= 1 - 0.35 * (((x - 0.5) ** 2 + (y - 0.5) ** 2) * 1.6)
    rgb = oklch_to_srgb(np.clip(L, 0, 1), C, h)
    rgb += rng.normal(0, 0.006, rgb.shape)  # grain
    return Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    for i, (name, hue, h2, h3) in enumerate(SETS):
        for dark in (False, True):
            img = field(i * 7 + 3, (hue, h2, h3), dark)
            fn = f"{name}-{'dark' if dark else 'light'}.webp"
            img.save(OUT / fn, quality=88)
        manifest.append({"id": name, "hue": hue})
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print("ok", [m["id"] for m in manifest])


if __name__ == "__main__":
    main()
