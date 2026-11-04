"""Token resolver: tokens/one.json -> concrete sRGB colors and metrics.

Mirrors prototypes/assets/engine.js computeVars so generated themes match the prototypes.
"""
import json
import math
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WALLS = {"dune": 55, "lagoon": 220, "orchid": 320, "moss": 150, "wave": 200}


def load_tokens():
    return json.loads((ROOT / "tokens" / "one.json").read_text())


def _oklch_to_linear(L, C, H):
    h = math.radians(H)
    a, b = C * math.cos(h), C * math.sin(h)
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    return (
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    )


def _gamma(x):
    x = min(max(x, 0.0), 1.0)
    return 12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055


@dataclass(frozen=True)
class Color:
    r: float
    g: float
    b: float
    a: float = 1.0

    @classmethod
    def oklch(cls, L, C, H, a=1.0):
        # Out-of-gamut values are clipped per channel, like Chromium does for the prototypes.
        rgb = _oklch_to_linear(min(max(L, 0.0), 1.0), C, H)
        return cls(*(_gamma(v) for v in rgb), a)

    @classmethod
    def hex(cls, s, a=1.0):
        s = s.lstrip("#")
        if len(s) == 3:
            s = "".join(c * 2 for c in s)
        return cls(int(s[0:2], 16) / 255, int(s[2:4], 16) / 255, int(s[4:6], 16) / 255, a)

    def with_alpha(self, a):
        return Color(self.r, self.g, self.b, a)

    def over(self, base):
        """Composite this (possibly translucent) color over an opaque base."""
        a = self.a
        return Color(*(s * a + d * (1 - a) for s, d in zip((self.r, self.g, self.b), (base.r, base.g, base.b))), 1.0)

    def mix(self, other, t):
        return Color(*(s + (o - s) * t for s, o in zip((self.r, self.g, self.b, self.a), (other.r, other.g, other.b, other.a))))

    @property
    def rgb255(self):
        return tuple(round(v * 255) for v in (self.r, self.g, self.b))

    @property
    def hexs(self):
        return "#%02x%02x%02x" % self.rgb255

    @property
    def hexa(self):
        """#RRGGBBAA (Kvantum, Qt)."""
        return self.hexs + "%02x" % round(self.a * 255)

    @property
    def argb(self):
        """#AARRGGBB (QML)."""
        return "#%02x" % round(self.a * 255) + self.hexs[1:]

    @property
    def kde(self):
        """KDE color scheme triple 'r,g,b'."""
        return ",".join(map(str, self.rgb255))

    @property
    def css(self):
        if self.a >= 1:
            return self.hexs
        r, g, b = self.rgb255
        return f"rgba({r},{g},{b},{self.a:.3f})"

    @property
    def svg(self):
        return self.hexs

    @property
    def luminance(self):
        def lin(c):
            return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

        return 0.2126 * lin(self.r) + 0.7152 * lin(self.g) + 0.0722 * lin(self.b)


WHITE = Color(1, 1, 1)
BLACK = Color(0, 0, 0)


def resolve(mode="light", accent="blue", wall="wave", tokens=None):
    """Return a Theme object with colors (Color) and metrics for one mode/accent."""
    t = tokens or load_tokens()
    if accent == "wallpaper":
        hue, chroma = WALLS[wall], 0.14
    else:
        hue, chroma = t["accents"][accent]["hue"], t["accents"][accent]["chroma"]
    dark = mode == "dark"
    n = t["color"]["neutral"][mode]
    nc = t["color"]["neutralChroma"]
    ink = WHITE if dark else BLACK
    c = {}
    for role in ("desktop", "canvas", "sidebar", "surface", "surfaceAlt", "float", "headerbar"):
        c[role] = Color.oklch(n[role], nc, hue)
    for role in ("text", "text2", "text3"):
        c[role] = Color.oklch(n[role], nc * 2, hue)
    c["stroke"] = ink.with_alpha(n["stroke"])
    c["strokeStrong"] = ink.with_alpha(n["strokeStrong"])
    c["hover"] = ink.with_alpha(0.07 if dark else 0.05)
    c["active"] = ink.with_alpha(0.12 if dark else 0.09)
    c["fill"] = ink.with_alpha(0.09 if dark else 0.06)
    c["fillStrong"] = ink.with_alpha(0.16 if dark else 0.12)
    aL = t["color"]["accent"][mode]
    c["accent"] = Color.oklch(aL, chroma, hue)
    c["accentHover"] = Color.oklch(aL + (0.04 if dark else -0.04), chroma, hue)
    c["accentPressed"] = Color.oklch(aL + (0.08 if dark else -0.08), chroma, hue)
    c["onAccent"] = Color.oklch(0.2, min(chroma, 0.06), hue) if aL > 0.68 else WHITE
    c["accentText"] = Color.oklch(max(aL, 0.76) if dark else min(aL, 0.52), chroma, hue)
    cL, ocL, cf = t["color"]["container"][mode]
    c["container"] = Color.oklch(cL, chroma * cf, hue)
    c["onContainer"] = Color.oklch(ocL, chroma * 0.8, hue)
    c["accentSoft"] = Color.oklch(aL, chroma, hue, 0.22 if dark else 0.14)
    for k, s in t["status"].items():
        c[k] = Color.oklch(0.74 if dark else 0.56, s["chroma"], s["hue"])
        c[k + "Soft"] = Color.oklch(0.74 if dark else 0.56, s["chroma"], s["hue"], 0.2 if dark else 0.13)
    g = t["glass"]
    # Glass flattened to one translucent color: tint layer over the luminosity layer.
    lum, tint = g["lum"][mode], g["tint"][mode]
    a = 1 - (1 - lum) * (1 - tint)
    base = BLACK if dark else WHITE
    c["glass"] = Color(*((tint * f + (1 - tint) * lum * b) / a for f, b in
                         zip((c["float"].r, c["float"].g, c["float"].b), (base.r, base.g, base.b))), a)
    return Theme(tokens=t, mode=mode, dark=dark, hue=hue, chroma=chroma, accent=accent, c=c)


@dataclass
class Theme:
    tokens: dict
    mode: str
    dark: bool
    hue: float
    chroma: float
    accent: str
    c: dict

    @property
    def shape(self):
        return self.tokens["shape"]

    @property
    def density(self):
        return self.tokens["density"]

    @property
    def glass(self):
        return self.tokens["glass"]

    def ok(self, L, C=None, H=None, a=1.0):
        return Color.oklch(L, self.chroma if C is None else C, self.hue if H is None else H, a)

    def flat(self, name, base="canvas"):
        """Opaque version of a translucent token composited over a base surface."""
        col = self.c[name]
        return col if col.a >= 1 else col.over(self.c[base])

    def ansi(self):
        """16 terminal colors derived from the same perceptual model."""
        dark = self.dark
        hues = {"red": 25, "green": 150, "yellow": 85, "blue": 255, "magenta": 330, "cyan": 200}
        L, Lb = (0.72, 0.80) if dark else (0.52, 0.60)
        C = 0.14
        out = {}
        bg = self.c["canvas"]
        out["black"] = self.ok(0.30 if dark else 0.25, 0.01)
        out["brightBlack"] = self.ok(0.50, 0.01)
        for k, h in hues.items():
            out[k] = Color.oklch(L, C, h)
            out["bright" + k.capitalize()] = Color.oklch(Lb, C * 0.9, h)
        out["white"] = self.ok(0.86 if dark else 0.80, 0.008)
        out["brightWhite"] = self.ok(0.97, 0.004)
        out["bg"] = bg
        out["fg"] = self.c["text"]
        return out
