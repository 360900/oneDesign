"""Aurorae (KWin) window decoration generator: unified header color, soft shadow, round buttons."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from plasma import Doc, _png

POS = ("topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom", "bottomright")


def paint(c, attr="fill"):
    s = f'{attr}="{c.hexs}"'
    if c.a < 0.999:
        s += f' {attr}-opacity="{c.a:.3f}"'
    return s


def _shadow_img(P, R, C, layers, s=2):
    """Raster shadow for a window whose rect is inset by P = (top, right, bottom, left)."""
    t, r_, b, l = P
    W, H = l + R + C + R + r_, t + R + C + R + b
    arr = np.zeros((H * s, W * s), np.float32)
    box = [l * s, t * s, (W - r_) * s - 1, (H - b) * s - 1]
    for alpha, dy, blur in layers:
        im = Image.new("L", (W * s, H * s), 0)
        ImageDraw.Draw(im).rounded_rectangle([box[0], box[1] + dy * s, box[2], box[3] + dy * s], radius=R * s, fill=255)
        im = im.filter(ImageFilter.GaussianBlur(blur * s / 2))
        arr = 1 - (1 - arr) * (1 - np.asarray(im, np.float32) / 255 * alpha)
    knock = Image.new("L", (W * s, H * s), 0)
    ImageDraw.Draw(knock).rounded_rectangle(box, radius=R * s, corners=(True, True, False, False), fill=255)
    arr *= 1 - np.asarray(knock, np.float32) / 255
    rgba = np.zeros((H * s, W * s, 4), np.uint8)
    rgba[..., 3] = np.clip(arr * 255, 0, 255).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA"), W, H


def _shape_img(P, R, C, fill, stroke, s=2, ss=4):
    """Window top with rounded top corners and an outer hairline, rasterized (QtSvg has no nested viewports)."""
    t, r_, b, l = P
    W, H = l + R + C + R + r_, t + R + C + R + b
    k = s * ss
    def layer(col, grow):
        im = Image.new("L", (W * k, H * k), 0)
        ImageDraw.Draw(im).rounded_rectangle(
            [(l - grow) * k, (t - grow) * k, (W - r_ + grow) * k - 1, (H - b + grow) * k - 1],
            radius=(R + grow) * k, corners=(True, True, False, False), fill=255)
        a = np.asarray(im.resize((W * s, H * s), Image.LANCZOS), np.float32) / 255 * col.a
        return np.dstack([np.full_like(a, v) for v in col.rgb255] + [a])
    def over(top, base):
        a = top[..., 3:] + base[..., 3:] * (1 - top[..., 3:])
        rgb = (top[..., :3] * top[..., 3:] + base[..., :3] * base[..., 3:] * (1 - top[..., 3:])) / np.maximum(a, 1e-6)
        return np.dstack([rgb, a])
    return over(layer(fill, 0), layer(stroke, 1))


def decoration_frame(doc, prefix, P, R, fill, stroke, layers, C=4, shadow=True):
    t, r_, b, l = P
    s = 2
    W, H = l + R + C + R + r_, t + R + C + R + b
    shape = _shape_img(P, R, C, fill, stroke, s)
    if shadow:
        sh, _, _ = _shadow_img(P, R, C, layers, s)
        sh = np.asarray(sh, np.float32)
        base = np.dstack([np.zeros(sh.shape[:2] + (3,), np.float32), sh[..., 3] / 255])
    else:
        base = np.zeros(shape.shape, np.float32)
    a = shape[..., 3:] + base[..., 3:] * (1 - shape[..., 3:])
    rgb = (shape[..., :3] * shape[..., 3:]) / np.maximum(a, 1e-6)
    img = Image.fromarray(np.clip(np.dstack([rgb, a * 255]), 0, 255).astype(np.uint8), "RGBA")
    x_cuts = [0, l + R, l + R + C, W]
    y_cuts = [0, t + R, t + R + C, H]
    for i, pos in enumerate(POS):
        cx, cy = i % 3, i // 3
        px, py = x_cuts[cx], y_cuts[cy]
        w, h = x_cuts[cx + 1] - px, y_cuts[cy + 1] - py
        if pos == "center":
            body = f'<rect width="{w}" height="{h}" {paint(fill)}/>'
        else:
            crop = img.crop((px * s, py * s, (px + w) * s, (py + h) * s))
            body = f'<image width="{w}" height="{h}" preserveAspectRatio="none" xlink:href="{_png(crop)}"/>'
        doc.add(f"{prefix}-{pos}", w, h, body)


def build(th, name):
    """Returns {filename: text} for share/aurorae/themes/<name>/."""
    c = th.c
    R = 12
    P = (26, 34, 42, 34)  # top right bottom left shadow padding
    head = c["headerbar"]
    stroke = c["strokeStrong"] if th.dark else c["stroke"]
    stroke_in = c["stroke"].with_alpha(c["stroke"].a * 0.7)
    a = 1.5 if th.dark else 1.0
    act = ((0.06 * a, 1, 3), (0.22 * a, 14, 36))
    ina = ((0.05 * a, 1, 3), (0.12 * a, 8, 24))
    d = Doc()
    decoration_frame(d, "decoration", P, R, head, stroke, act)
    decoration_frame(d, "decoration-inactive", P, R, head, stroke_in, ina)
    decoration_frame(d, "decoration-opaque", P, R, head, stroke, act, shadow=False)
    decoration_frame(d, "decoration-opaque-inactive", P, R, head, stroke_in, ina, shadow=False)
    for pre in ("decoration-maximized", "decoration-maximized-inactive",
                "decoration-maximized-opaque", "decoration-maximized-opaque-inactive"):
        for pos in POS:
            d.add(f"{pre}-{pos}", 4, 4, f'<rect width="4" height="4" {paint(head)}/>' if pos == "center" else "")
    files = {"decoration.svg": d.text()}

    S = 24
    ink = c["text"]
    glyphs = {
        "close": "M8.5,8.5 L15.5,15.5 M15.5,8.5 L8.5,15.5",
        "minimize": "M8,12.5 H16",
        "maximize": "M8.5,8.5 H15.5 V15.5 H8.5 Z",
        "restore": "M8.5,10.5 H13.5 V15.5 H8.5 Z M10.5,10.5 V8.5 H15.5 V13.5 H13.5",
        "alldesktops": "M12,8 V16 M8,12 H16",
        "keepabove": "M8.5,13.5 L12,10 L15.5,13.5",
        "keepbelow": "M8.5,10.5 L12,14 L15.5,10.5",
        "shade": "M8.5,11 H15.5 M8.5,14 H15.5",
        "help": "M10,10 A2,2 0 1 1 12.5,12 C12,12.3 12,12.8 12,13.5 M12,15.6 V15.7",
    }

    def btn(bg_a, fg, fg_a=1.0, close_hover=False):
        bg = (c["danger"] if close_hover else ink).with_alpha(bg_a)
        gc = c["onAccent"] if close_hover else fg
        return bg, gc.with_alpha(fg_a)

    states = {
        "active": (0.08, 1.0), "hover": (0.14, 1.0), "pressed": (0.20, 1.0),
        "inactive": (0.05, 0.55), "hover-inactive": (0.12, 0.9), "pressed-inactive": (0.18, 0.9),
        "deactivated": (0.03, 0.3), "deactivated-inactive": (0.03, 0.25),
    }
    for kind, g in glyphs.items():
        bd = Doc()
        for st, (ba, fa) in states.items():
            bg, gc = btn(ba, ink, fa)
            if kind == "close" and st in ("hover", "pressed"):
                bg = c["danger"].with_alpha(1.0 if st == "hover" else 0.85)
                gc = WHITE_LIKE(c)
            body = (f'<circle cx="12" cy="12" r="11" {paint(bg)}/>'
                    f'<path d="{g}" fill="none" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" {paint(gc, "stroke")}/>')
            bd.add(f"{st}-center", S, S, body)
        files[f"{kind}.svg"] = bd.text()

    tc = lambda col: ",".join(str(v) for v in col.rgb255) + ",255"
    files[f"{name}rc"] = f"""[General]
TitleAlignment=Center
TitleVerticalAlignment=Center
Animation=120
ActiveTextColor={tc(c['text'])}
InactiveTextColor={tc(c['text3'].over(head))}
UseTextShadow=false
HaloActive=false
HaloInactive=false
LeftButtons=
RightButtons=IAX
Shadow=true
DecorationPosition=0

[Layout]
BorderLeft=0
BorderRight=0
BorderBottom=0
TitleEdgeTop=12
TitleEdgeBottom=12
TitleEdgeLeft=12
TitleEdgeRight=12
TitleEdgeTopMaximized=6
TitleEdgeBottomMaximized=6
TitleEdgeLeftMaximized=8
TitleEdgeRightMaximized=8
TitleBorderLeft=8
TitleBorderRight=8
TitleHeight={S}
ButtonWidth={S}
ButtonHeight={S}
ButtonSpacing=8
ButtonMarginTop=0
ExplicitButtonSpacer=8
PaddingTop={P[0]}
PaddingRight={P[1]}
PaddingBottom={P[2]}
PaddingLeft={P[3]}
"""
    files["metadata.desktop"] = f"""[Desktop Entry]
Name={name.replace('One', 'One ')}
Comment=oneDesign window decoration
X-KDE-PluginInfo-Name={name}
X-KDE-PluginInfo-Author=oneDesign
X-KDE-PluginInfo-Version=0.1
X-KDE-PluginInfo-License=GPL-3.0-or-later
X-KDE-ServiceTypes=KWin/Decoration
"""
    return files


def WHITE_LIKE(c):
    from onetokens import WHITE
    return WHITE
