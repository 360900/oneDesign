"""Plasma style (desktoptheme) generator.

Colors come from the active color scheme through Plasma's `current-color-scheme`
stylesheet, so the same SVGs serve light and dark. Missing files fall back to the
default (Breeze) theme.
"""
import base64
import io
import json

import numpy as np

from PIL import Image, ImageDraw, ImageFilter

POS = ("topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom", "bottomright")
SIDES = ("top", "bottom", "left", "right")

STYLE = """<style type="text/css" id="current-color-scheme">
.ColorScheme-Text{color:#232629;}
.ColorScheme-Background{color:#eff0f1;}
.ColorScheme-Highlight{color:#3daee9;}
.ColorScheme-HighlightedText{color:#ffffff;}
.ColorScheme-ViewBackground{color:#fcfcfc;}
.ColorScheme-ButtonBackground{color:#eff0f1;}
.ColorScheme-NegativeText{color:#da4453;}
.ColorScheme-NeutralText{color:#f67400;}
</style>"""


def cs(role, a=1.0, attr="fill"):
    """Paint from a color-scheme role (Text, Background, Highlight, ...) or a literal #hex."""
    if role.startswith("#"):
        s = f'{attr}="{role}"'
    else:
        s = f'class="ColorScheme-{role}" {attr}="currentColor"'
    if a < 0.999:
        s += f' {attr}-opacity="{a:.3f}"'
    return s


class Doc:
    def __init__(self):
        self.parts = []
        self.x = self.y = self.row = 0
        self.defs = []

    def slot(self, w, h):
        if self.x + w > 1200:
            self.x, self.y, self.row = 0, self.y + self.row + 6, 0
        x, y = self.x, self.y
        self.x += w + 6
        self.row = max(self.row, h)
        return x, y

    def add(self, ident, w, h, body=""):
        x, y = self.slot(w, h)
        self.parts.append(f'<g id="{ident}" transform="translate({x},{y})">'
                          f'<rect width="{w}" height="{h}" fill="#000" fill-opacity="0"/>{body}</g>')

    def hint(self, ident, w, h):
        x, y = self.slot(w, h)
        self.parts.append(f'<rect id="{ident}" x="{x}" y="{y}" width="{w}" height="{h}" fill="#f0f" fill-opacity="0"/>')

    def text(self):
        h = self.y + self.row + 6
        return ('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
                f'width="1200" height="{h}" viewBox="0 0 1200 {h}">\n{STYLE}\n'
                + (f"<defs>{''.join(self.defs)}</defs>\n" if self.defs else "") + "\n".join(self.parts) + "\n</svg>\n")


def _rr(x, y, w, h, r):
    r = max(0, min(r, w / 2, h / 2))
    return (f"M{x + r},{y} H{x + w - r} A{r},{r} 0 0 1 {x + w},{y + r} V{y + h - r} "
            f"A{r},{r} 0 0 1 {x + w - r},{y + h} H{x + r} A{r},{r} 0 0 1 {x},{y + h - r} "
            f"V{y + r} A{r},{r} 0 0 1 {x + r},{y} Z")


def _corner(B, m, r):
    if r <= 0:
        return f"M{m},{m} H{B} V{B} H{m} Z"
    return f"M{m},{m + r} A{r},{r} 0 0 1 {m + r},{m} H{B} V{B} H{m} Z"


_FLIP = {"topleft": "", "topright": "translate({B},0) scale(-1,1)",
         "bottomleft": "translate(0,{B}) scale(1,-1)", "bottomright": "translate({B},{B}) scale(-1,-1)"}


def frame(doc, prefix, B, layers, margins=None, C=4, extra=None):
    """Nine-slice a box made of rounded-rect layers into `prefix-<pos>` pieces.

    layers: (inset, radius, paint, kind) with kind 'fill' or ('stroke', width);
    paint may be a callable(pos) returning the paint for that piece.
    extra: {pos: svg body} drawn on top of a piece.
    """
    pre = f"{prefix}-" if prefix else ""
    extra = extra or {}
    for pos in POS:
        body = ""
        layers_ = layers
        layers = [(i, r, p(pos) if callable(p) else p, k) for i, r, p, k in layers_]
        if pos in _FLIP:
            for inset, r, paint, kind in layers:
                r = min(r, B - inset) if r > 0 else 0
                if kind == "fill":
                    body += f'<path d="{_corner(B, inset, r)}" {paint}/>'
                else:
                    sw = kind[1]
                    body += f'<path d="{_corner(B, inset, r)} {_corner(B, inset + sw, max(r - sw, 0))}" fill-rule="evenodd" {paint}/>'
            if body and _FLIP[pos]:
                body = f'<g transform="{_FLIP[pos].format(B=B)}">{body}</g>'
            w = h = B
        elif pos == "center":
            w = h = C
            for inset, r, paint, kind in layers:
                if kind == "fill":
                    body += f'<rect width="{C}" height="{C}" {paint}/>'
        else:
            horiz = pos in ("top", "bottom")
            w, h = (C, B) if horiz else (B, C)
            for inset, r, paint, kind in layers:
                a, b = (inset, B) if kind == "fill" else (inset, inset + kind[1])
                if b <= a:
                    continue
                if horiz:
                    y0 = a if pos == "top" else B - b
                    body += f'<rect x="0" y="{y0}" width="{C}" height="{b - a}" {paint}/>'
                else:
                    x0 = a if pos == "left" else B - b
                    body += f'<rect x="{x0}" y="0" width="{b - a}" height="{C}" {paint}/>'
        body += extra.get(pos, "")
        doc.add(pre + pos, w, h, body)
        layers = layers_
    if margins is not None:
        m = margins if isinstance(margins, dict) else dict.fromkeys(SIDES, margins)
        for s in SIDES:
            v = m[s]
            doc.hint(f"{pre}hint-{s}-margin", 4 if s in ("top", "bottom") else v, v if s in ("top", "bottom") else 4)


def _png(img):
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def shadow(doc, r, S=32, layers=((0.10, 2, 4), (0.20, 8, 18)), scale=2, prefix="shadow"):
    """Soft drop shadow pieces for KWin, with the window area knocked out.

    Pieces are S + r thick; `shadow-hint-*-margin` = S tells Plasma how far the
    shadow extends outside the window, the remaining r overlaps the rounded corner.
    layers: (alpha, dy, blur).
    """
    T = S + r
    C = 4
    W = 2 * T + C
    s = scale
    arr = np.zeros((W * s, W * s), np.float32)
    for alpha, dy, blur in layers:
        im = Image.new("L", (W * s, W * s), 0)
        ImageDraw.Draw(im).rounded_rectangle([S * s, (S + dy) * s, (W - S) * s - 1, (W - S + dy) * s - 1],
                                             radius=r * s, fill=255)
        im = im.filter(ImageFilter.GaussianBlur(blur * s / 2))
        a = np.asarray(im, np.float32) / 255 * alpha
        arr = 1 - (1 - arr) * (1 - a)
    arr *= 255
    knock = Image.new("L", (W * s, W * s), 0)
    ImageDraw.Draw(knock).rounded_rectangle([S * s, S * s, (W - S) * s - 1, (W - S) * s - 1], radius=r * s, fill=255)
    arr = arr * (1 - np.asarray(knock) / 255)
    rgba = np.zeros((W * s, W * s, 4), np.uint8)
    rgba[..., 3] = np.clip(arr, 0, 255).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA")
    for pos in POS:
        x0 = 0 if "left" in pos else T + C if "right" in pos else T
        y0 = 0 if pos.startswith("top") else T + C if pos.startswith("bottom") else T
        w = T if ("left" in pos or "right" in pos) else C
        h = T if (pos.startswith("top") or pos.startswith("bottom")) else C
        if pos == "center":
            doc.add(f"{prefix}-center", w, h)
            continue
        crop = img.crop((x0 * s, y0 * s, (x0 + w) * s, (y0 + h) * s))
        doc.add(f"{prefix}-{pos}", w, h, f'<image width="{w}" height="{h}" preserveAspectRatio="none" xlink:href="{_png(crop)}"/>')
    for sd in SIDES:
        doc.hint(f"{prefix}-hint-{sd}-margin", 4 if sd in ("top", "bottom") else S, S if sd in ("top", "bottom") else 4)


# --------------------------------------------------------------------------- surfaces

def _row(pos):
    return "top" if pos.startswith("top") else "bottom" if pos.startswith("bottom") else "mid"


SHEEN = 0.07


def glass_layers(r, alpha, rim=True):
    """Floating glass: tinted fill, light sheen fading down, hairline, specular rim lit from above."""
    L = [(0, r, cs("Background", alpha), "fill")]
    if rim:
        L.append((0, r, lambda p: {"top": cs("#ffffff", SHEEN), "mid": 'fill="url(#sheen)"'}.get(_row(p), 'fill="none"'), "fill"))
    L.append((0, r, cs("#000000", 0.14), ("stroke", 1)))
    if rim:
        L.append((1, r - 1, lambda p: cs("#ffffff", {"top": 0.38, "mid": 0.07, "bottom": 0.03}[_row(p)]), ("stroke", 1)))
    return L


def surface_svg(r, alpha, pad, S=32, with_shadow=True, shadow_layers=None, thick=False):
    d = Doc()
    d.defs.append(f'<linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity="{SHEEN}"/>'
                  '<stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>')
    B = max(r, 4)
    frame(d, "", B, glass_layers(r, alpha), pad)
    d.hint("hint-stretch-borders", 4, 4)
    for s in SIDES:
        d.hint(f"hint-{s}-inset", 4 if s in ("top", "bottom") else 0.01, 0.01 if s in ("top", "bottom") else 4)
    frame(d, "mask", B, [(0, r, 'fill="#000"', "fill")])
    if with_shadow:
        shadow(d, r, S, shadow_layers or ((0.07, 1, 3), (0.20, 10, 26)))
    if thick:
        for s in SIDES:
            v = pad if isinstance(pad, int) else pad[s]
            v += 2 if s in ("top", "bottom") else 0
            d.hint(f"thick-hint-{s}-margin", 4 if s in ("top", "bottom") else v, v if s in ("top", "bottom") else 4)
        d.add("thick-center", 4, 4)
    return d.text()


# --------------------------------------------------------------------------- widgets

def states_svg(prefixes, B, r, margins, stroke_focus=None):
    """Generic multi-state frame file. prefixes: {prefix: layers}"""
    d = Doc()
    for p, layers in prefixes.items():
        frame(d, p, B, layers, margins.get(p, margins.get("*")) if isinstance(margins, dict) else margins)
    return d.text()


def button_svg(r):
    B = r
    t = lambda a: [(0, r, cs("Text", a), "fill")]
    ring = [(0, r, cs("Highlight", 0.9), ("stroke", 2))]
    m = {"*": 6}
    d = Doc()
    for p, layers in {"normal": t(0.07), "hover": t(0.11), "pressed": t(0.16),
                      "focus": ring, "toolbutton-hover": t(0.08), "toolbutton-pressed": t(0.14),
                      "toolbutton-focus": ring}.items():
        frame(d, p, B, layers, 6)
    for s in SIDES:
        d.hint(f"shadow-hint-{s}-margin", 4 if s in ("top", "bottom") else 0.01, 0.01 if s in ("top", "bottom") else 4)
    for pos in POS:
        d.add(f"shadow-{pos}", 4, 4)
    frame(d, "mask-normal", B, [(0, r, 'fill="#000"', "fill")])
    return d.text()


def lineedit_svg(r):
    B = r
    d = Doc()
    base = [(0, r, cs("Text", 0.07), "fill")]
    frame(d, "base", B, base, 8)
    frame(d, "hover", B, [(0, r, cs("Text", 0.04), "fill")], 8)
    frame(d, "focus", B, [(0, r, cs("Highlight", 1), ("stroke", 2))], 8)
    frame(d, "focusframe", B, [(0, r, cs("Highlight", 1), ("stroke", 2))])
    d.hint("hint-focus-over-base", 4, 4)
    return d.text()


def viewitem_svg(r):
    d = Doc()
    for p, layers in {"normal": [], "hover": [(0, r, cs("Text", 0.07), "fill")],
                      "selected": [(0, r, cs("Highlight", 0.22), "fill")],
                      "selected+hover": [(0, r, cs("Highlight", 0.30), "fill")]}.items():
        frame(d, p, r, layers, 6)
    return d.text()


def listitem_svg(r):
    d = Doc()
    for p, layers in {"normal": [], "hover": [(0, r, cs("Text", 0.07), "fill")],
                      "pressed": [(0, r, cs("Highlight", 0.22), "fill")],
                      "section": []}.items():
        frame(d, p, r, layers, 6)
    d.add("separator", 4, 1, f'<rect width="4" height="1" {cs("Text", 0.10)}/>')
    return d.text()


TASK_W = 68  # icontasks tile width in the 60px dock


def dot_frame(doc, prefix, dw, paint, side="south", W=TASK_W, t=4):
    """Transparent task frame whose only visible part is a short indicator bar of
    width dw on one edge. Side borders take the remaining width so the bar stays
    centered and does not stretch across the tile."""
    L = (W - dw) / 2
    E, F = 2, t + 3  # far edge, indicator edge
    bar = lambda w, h, x, y: f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{min(w, h) / 2}" {paint}/>'
    if side in ("south", "north"):
        top, bottom = (E, F) if side == "south" else (F, E)
        y = F - t - 1 if side == "south" else 1
        sizes = {"topleft": (L, top), "top": (dw, top), "topright": (L, top), "left": (L, 4), "center": (dw, 4),
                 "right": (L, 4), "bottomleft": (L, bottom), "bottom": (dw, bottom), "bottomright": (L, bottom)}
        edge = "bottom" if side == "south" else "top"
        body = {edge: bar(dw, t, 0, y)}
    else:
        left, right = (E, F) if side == "east" else (F, E)
        x = F - t - 1 if side == "east" else 1
        sizes = {"topleft": (left, L), "top": (4, L), "topright": (right, L), "left": (left, dw), "center": (4, dw),
                 "right": (right, dw), "bottomleft": (left, L), "bottom": (4, L), "bottomright": (right, L)}
        edge = "right" if side == "east" else "left"
        body = {edge: bar(t, dw, x, 0)}
    for pos, (w, h) in sizes.items():
        doc.add(f"{prefix}-{pos}", w, h, body.get(pos, ""))


def tasks_svg(r):
    """Dock task buttons: no tile behind open apps, only a centered indicator
    (short dot when running, wider accent bar for the active window). Hover keeps
    a soft tile as pointer feedback."""
    d = Doc()
    indicators = {
        "normal": (8, cs("Text", 0.75)),
        "focus": (20, cs("Highlight", 1)),
        "minimized": (8, cs("Text", 0.4)),
        "attention": (8, cs("NeutralText", 1)),
    }
    sides = {"": "south", "north-": "north", "east-": "east", "west-": "west"}
    for loc, side in sides.items():
        for st, (dw, paint) in indicators.items():
            dot_frame(d, f"{loc}{st}", dw, paint, side)
        frame(d, f"{loc}hover", r, [(0, r, cs("Text", 0.08), "fill")])
        frame(d, f"{loc}progress", r, [(0, r, cs("Highlight", 0.22), "fill")])
    for s in SIDES:
        d.hint(f"normal-hint-{s}-margin", 4, 4)
    for g in ("bottom", "left", "top", "right"):
        d.add(f"group-expander-{g}", 8, 8, f'<circle cx="4" cy="4" r="2" {cs("Text", 0.6)}/>')
    d.hint("hint-stretch-borders", 4, 4)
    return d.text()


def inset_frame(doc, prefix, r, ix, iy, paint, C=4):
    """Rounded fill inset by transparent ix/iy borders, so a highlight stretched over
    the whole panel thickness stays compact."""
    w, h = ix + r, iy + r
    corner = f"M{ix},{iy + r} A{r},{r} 0 0 1 {ix + r},{iy} H{w} V{h} H{ix} Z"
    flips = {"topleft": "", "topright": f"translate({w},0) scale(-1,1)",
             "bottomleft": f"translate(0,{h}) scale(1,-1)", "bottomright": f"translate({w},{h}) scale(-1,-1)"}
    for pos, tf in flips.items():
        doc.add(f"{prefix}-{pos}", w, h, f'<path d="{corner}" {paint}' + (f' transform="{tf}"/>' if tf else "/>"))
    doc.add(f"{prefix}-top", C, h, f'<rect y="{iy}" width="{C}" height="{r}" {paint}/>')
    doc.add(f"{prefix}-bottom", C, h, f'<rect width="{C}" height="{r}" {paint}/>')
    doc.add(f"{prefix}-left", w, C, f'<rect x="{ix}" width="{r}" height="{C}" {paint}/>')
    doc.add(f"{prefix}-right", w, C, f'<rect width="{r}" height="{C}" {paint}/>')
    doc.add(f"{prefix}-center", C, C, f'<rect width="{C}" height="{C}" {paint}/>')


def tabbar_svg(r, inset):
    """Expanded-applet highlight. Plasma stretches it across the panel thickness
    (and for tray items across the side margins), so inset it on the thickness axis."""
    d = Doc()
    for loc in ("north", "south", "east", "west"):
        ix, iy = (0, inset) if loc in ("north", "south") else (inset, 0)
        inset_frame(d, f"{loc}-active-tab", r, ix, iy, cs("Text", 0.10))
    return d.text()


def heading_svg():
    """Popup headers and footers stay flush with the popup: no band, only margins."""
    d = Doc()
    frame(d, "header", 4, [], None)
    frame(d, "footer", 4, [], None)
    for s in SIDES:
        d.hint(f"hint-{s}-margin", 4 if s in ("top", "bottom") else 6, 6 if s in ("top", "bottom") else 4)
    d.hint("hint-stretch-borders", 4, 4)
    return d.text()


# --------------------------------------------------------------------------- package

def metadata(name, ident, desc):
    return json.dumps({
        "KPlugin": {"Authors": [{"Name": "oneDesign"}], "Description": desc, "EnabledByDefault": True,
                    "Id": ident, "License": "GPL-3.0-or-later", "Name": name, "Version": "0.1",
                    "Website": "https://github.com/"},
        "X-Plasma-API": "5.0"}, indent=2) + "\n"


PLASMARC = """[Wallpaper]
defaultWallpaperTheme=One-Lagoon
defaultFileSuffix=.png
defaultWidth=2400
defaultHeight=1500

[AdaptiveTransparency]
enabled=true

[ContrastEffect]
enabled=true
contrast=0.2
intensity=1.2
saturation=1.4

[BlurBehindEffect]
enabled=true
"""


# Side margins are small: Plasma extends the tray highlight by them, overlapping neighbors.
PANEL_PAD = {"top": 6, "bottom": 6, "left": 2, "right": 2}


def build(th, ident="One"):
    """Returns {relative path: text} for share/plasma/desktoptheme/<ident>/."""
    sh = th.shape
    rw, rc, rctl = sh["window"], sh["container"], sh["control"]
    a_glass = 0.45
    files = {}

    panel = lambda alpha, sh_=True: surface_svg(rc, alpha, PANEL_PAD, S=24, with_shadow=sh_,
                                                shadow_layers=((0.06, 1, 3), (0.16, 6, 18)), thick=True)
    dialog = lambda alpha, sh_=True: surface_svg(rc, alpha, 10, S=40, with_shadow=sh_,
                                                 shadow_layers=((0.06, 1, 2), (0.14, 10, 30)))
    tooltip = lambda alpha, sh_=True: surface_svg(rctl, alpha, 8, S=24, with_shadow=sh_,
                                                  shadow_layers=((0.06, 1, 2), (0.16, 6, 14)))
    widget = lambda alpha, sh_=True: surface_svg(rw, alpha, 14, S=32, with_shadow=sh_,
                                                 shadow_layers=((0.05, 1, 3), (0.12, 8, 22)))

    for sub, alpha, sh_ in (("", 0.96, True), ("translucent/", a_glass, True), ("solid/", 1.0, True), ("opaque/", 1.0, False)):
        files[f"{sub}widgets/panel-background.svg"] = panel(alpha, sh_)
        files[f"{sub}dialogs/background.svg"] = dialog(alpha, sh_)
        files[f"{sub}widgets/tooltip.svg"] = tooltip(alpha, sh_)
        if sub != "opaque/":
            files[f"{sub}widgets/background.svg"] = widget(alpha, sh_)
    files["widgets/button.svg"] = button_svg(rctl)
    files["widgets/lineedit.svg"] = lineedit_svg(rctl)
    files["widgets/viewitem.svg"] = viewitem_svg(sh["small"] + 2)
    files["widgets/listitem.svg"] = listitem_svg(sh["small"] + 2)
    files["widgets/tasks.svg"] = tasks_svg(rctl)
    files["widgets/tabbar.svg"] = tabbar_svg(sh["small"] + 2, 5)
    files["widgets/plasmoidheading.svg"] = heading_svg()
    files["metadata.json"] = metadata("One", ident, "oneDesign Plasma style")
    files["plasmarc"] = PLASMARC
    return files
