"""Kvantum theme generator (Qt widget style) for a resolved oneDesign theme."""
import base64
import io

from PIL import Image, ImageDraw, ImageFilter

from onetokens import Color, WHITE

STATES = ("normal", "focused", "pressed", "toggled", "disabled")
POS = ("top", "bottom", "left", "right", "topleft", "topright", "bottomleft", "bottomright")


def paint(c, attr="fill"):
    if c is None:
        return f'{attr}="none"'
    s = f'{attr}="{c.hexs}"'
    if c.a < 0.999:
        s += f' {attr}-opacity="{c.a:.3f}"'
    return s


class Svg:
    """Collects elements; every element gets its own slot so bounds never overlap."""

    def __init__(self):
        self.parts = []
        self.x = self.y = self.row = 0

    def slot(self, w, h):
        if self.x + w > 1600:
            self.x, self.y, self.row = 0, self.y + self.row + 4, 0
        x, y = self.x, self.y
        self.x += w + 4
        self.row = max(self.row, h)
        return x, y

    def add(self, ident, w, h, body=""):
        x, y = self.slot(w, h)
        self.parts.append(
            f'<g id="{ident}" transform="translate({x},{y})">'
            f'<rect width="{w}" height="{h}" fill="#000" fill-opacity="0"/>{body}</g>')

    def text(self):
        w = 1600
        h = self.y + self.row + 4
        return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
                f'width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n' + "\n".join(self.parts) + "\n</svg>\n")


def _corner(F, m, r):
    if r <= 0:
        return f"M{m},{m} L{F},{m} L{F},{F} L{m},{F} Z"
    return f"M{m},{m + r} A{r},{r} 0 0 1 {m + r},{m} L{F},{m} L{F},{F} L{m},{F} Z"


_FLIP = {
    "topleft": "",
    "topright": "translate({F},0) scale(-1,1)",
    "bottomleft": "translate(0,{F}) scale(1,-1)",
    "bottomright": "translate({F},{F}) scale(-1,-1)",
}


def rr_frame(svg, ident, F, r, fill=None, stroke=None, sw=1.0, inset=0.0, interior=None):
    """Nine-slice a rounded rect: frame pieces `ident-<pos>` (+ optional interior id)."""
    r = min(r, F - inset)
    for pos, tf in _FLIP.items():
        body = ""
        if stroke is not None:
            ring = _corner(F, inset, r) + " " + _corner(F, inset + sw, max(r - sw, 0))
            body += f'<path d="{ring}" fill-rule="evenodd" {paint(stroke)}/>'
            if fill is not None:
                body += f'<path d="{_corner(F, inset + sw, max(r - sw, 0))}" {paint(fill)}/>'
        elif fill is not None:
            body += f'<path d="{_corner(F, inset, r)}" {paint(fill)}/>'
        if body and tf:
            body = f'<g transform="{tf.format(F=F)}">{body}</g>'
        svg.add(f"{ident}-{pos}", F, F, body)
    for pos in ("top", "bottom", "left", "right"):
        body = ""
        horiz = pos in ("top", "bottom")
        inner = inset + (sw if stroke is not None else 0)

        def band(a, b, c):
            if b <= a:
                return ""
            if horiz:
                y0 = a if pos == "top" else F - b
                return f'<rect x="0" y="{y0}" width="{F}" height="{b - a}" {paint(c)}/>'
            x0 = a if pos == "left" else F - b
            return f'<rect x="{x0}" y="0" width="{b - a}" height="{F}" {paint(c)}/>'

        if stroke is not None:
            body += band(inset, inset + sw, stroke)
        if fill is not None:
            body += band(inner, F, fill)
        svg.add(f"{ident}-{pos}", F, F, body)
    if interior:
        svg.add(interior, 8, 8, f'<rect width="8" height="8" {paint(fill)}/>' if fill is not None else "")


def line_frame(svg, ident, F=1, color=None, sides=("bottom",)):
    for pos in POS:
        body = ""
        if pos in sides and color is not None:
            if pos in ("top", "bottom"):
                body = f'<rect width="4" height="{F}" {paint(color)}/>'
            else:
                body = f'<rect width="{F}" height="4" {paint(color)}/>'
        w, h = (4, F) if pos in ("top", "bottom") else (F, 4) if pos in ("left", "right") else (F, F)
        svg.add(f"{ident}-{pos}", w, h, body)


def flat_interior(svg, ident, color):
    svg.add(ident, 8, 8, f'<rect width="8" height="8" {paint(color)}/>' if color is not None else "")


def _png_uri(img):
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def shadow_frame(svg, ident, F, D, r, fill, stroke, alpha, dy=3, blur=None, scale=3):
    """Popup frame with a soft raster shadow outside and a vector surface inside.

    Pieces are T = F + D thick. Also writes `ident-shadow-hint-*` so Kvantum knows
    which part of each piece is pure shadow.
    """
    T = F + D
    E = 4
    W = 2 * T + E
    s = scale
    blur = blur or D * 0.45
    big = Image.new("L", (W * s, W * s), 0)
    d = ImageDraw.Draw(big)
    d.rounded_rectangle([D * s, (D + dy) * s, (W - D) * s - 1, (W - D + dy) * s - 1], radius=r * s, fill=int(255 * alpha))
    big = big.filter(ImageFilter.GaussianBlur(blur * s))
    knock = Image.new("L", big.size, 0)
    ImageDraw.Draw(knock).rounded_rectangle([D * s, D * s, (W - D) * s - 1, (W - D) * s - 1], radius=r * s, fill=255)
    big = Image.composite(Image.new("L", big.size, 0), big, knock)
    rgba = Image.new("RGBA", big.size, (0, 0, 0, 0))
    rgba.putalpha(big)

    boxes = {
        "topleft": (0, 0, T, T), "topright": (T + E, 0, W, T),
        "bottomleft": (0, T + E, T, W), "bottomright": (T + E, T + E, W, W),
        "top": (T, 0, T + E, T), "bottom": (T, T + E, T + E, W),
        "left": (0, T, T, T + E), "right": (T + E, T, W, T + E),
    }
    surf = Svg()
    for pos, (x0, y0, x1, y1) in boxes.items():
        w, h = x1 - x0, y1 - y0
        crop = rgba.crop((x0 * s, y0 * s, x1 * s, y1 * s))
        body = f'<image width="{w}" height="{h}" preserveAspectRatio="none" xlink:href="{_png_uri(crop)}"/>'
        # vector surface clipped to the piece: draw the full popup rect translated, then mask by geometry
        if pos in _FLIP:
            tf = _FLIP[pos]
            sub = ""
            ring = _corner(T, D, r) + " " + _corner(T, D + 1, max(r - 1, 0))
            sub += f'<path d="{ring}" fill-rule="evenodd" {paint(stroke)}/>'
            sub += f'<path d="{_corner(T, D + 1, max(r - 1, 0))}" {paint(fill)}/>'
            body += f'<g transform="{tf.format(F=T)}">{sub}</g>' if tf else sub
        else:
            if pos == "top":
                body += f'<rect x="0" y="{D}" width="{w}" height="1" {paint(stroke)}/><rect x="0" y="{D + 1}" width="{w}" height="{T - D - 1}" {paint(fill)}/>'
            elif pos == "bottom":
                body += f'<rect x="0" y="{F - 1}" width="{w}" height="1" {paint(stroke)}/><rect x="0" y="0" width="{w}" height="{F - 1}" {paint(fill)}/>'
            elif pos == "left":
                body += f'<rect x="{D}" y="0" width="1" height="{h}" {paint(stroke)}/><rect x="{D + 1}" y="0" width="{T - D - 1}" height="{h}" {paint(fill)}/>'
            else:
                body += f'<rect x="{F - 1}" y="0" width="1" height="{h}" {paint(stroke)}/><rect x="0" y="0" width="{F - 1}" height="{h}" {paint(fill)}/>'
        svg.add(f"{ident}-shadow-{pos}", w, h, body)
    del surf
    for pos in ("top", "bottom", "left", "right"):
        if pos in ("top", "bottom"):
            svg.add(f"{ident}-shadow-hint-{pos}", E, D)
        else:
            svg.add(f"{ident}-shadow-hint-{pos}", D, E)


def chevron(svg, ident, direction, color, size=16, sw=1.6):
    pts = {"down": "M4.5,6.5 L8,10 L11.5,6.5", "up": "M4.5,9.5 L8,6 L11.5,9.5",
           "right": "M6.5,4.5 L10,8 L6.5,11.5", "left": "M9.5,4.5 L6,8 L9.5,11.5"}[direction]
    k = size / 16
    body = (f'<path d="{pts}" transform="scale({k})" fill="none" stroke-width="{sw}" stroke-linecap="round" '
            f'stroke-linejoin="round" {paint(color, "stroke")}/>') if color is not None else ""
    svg.add(ident, size, size, body)


def glyph(svg, ident, kind, color, size=16, sw=1.6):
    d = {"plus": "M8,3.5 V12.5 M3.5,8 H12.5", "minus": "M3.5,8 H12.5",
         "close": "M4.5,4.5 L11.5,11.5 M11.5,4.5 L4.5,11.5",
         "max": "M4.5,4.5 H11.5 V11.5 H4.5 Z", "min": "M4.5,11 H11.5",
         "restore": "M4.5,6.5 H9.5 V11.5 H4.5 Z M6.5,6.5 V4.5 H11.5 V9.5 H9.5",
         "menu": "M3.5,5 H12.5 M3.5,8 H12.5 M3.5,11 H12.5"}[kind]
    k = size / 16
    svg.add(ident, size, size,
            f'<path d="{d}" transform="scale({k})" fill="none" stroke-width="{sw}" stroke-linecap="round" '
            f'stroke-linejoin="round" {paint(color, "stroke")}/>')


def check_el(svg, ident, kind, box, size, accent, on_accent, border, fill, sw=2):
    """Checkbox/radio element. kind: box|box-on|box-tri|radio|radio-on."""
    s = size
    r = s / 2 if kind.startswith("radio") else 5 * s / 18
    body = ""
    if kind in ("box", "radio"):
        if fill is not None:
            body += f'<rect x="{sw / 2}" y="{sw / 2}" width="{s - sw}" height="{s - sw}" rx="{r - sw / 2}" {paint(fill)}/>'
        body += (f'<rect x="{sw / 2}" y="{sw / 2}" width="{s - sw}" height="{s - sw}" rx="{r - sw / 2}" fill="none" '
                 f'stroke-width="{sw}" {paint(border, "stroke")}/>')
    else:
        body += f'<rect width="{s}" height="{s}" rx="{r}" {paint(accent)}/>'
        k = s / 18
        if kind == "box-on":
            body += (f'<path d="M5,9.4 L7.8,12.2 L13.2,6.4" transform="scale({k})" fill="none" stroke-width="2.2" '
                     f'stroke-linecap="round" stroke-linejoin="round" {paint(on_accent, "stroke")}/>')
        elif kind == "box-tri":
            body += f'<rect x="{5 * k}" y="{8 * k}" width="{8 * k}" height="{2.2 * k}" rx="{1.1 * k}" {paint(on_accent)}/>'
        else:
            body += f'<circle cx="{s / 2}" cy="{s / 2}" r="{s * 0.2}" {paint(on_accent)}/>'
    svg.add(ident, box, box, f'<g transform="translate({(box - s) / 2},{(box - s) / 2})">{body}</g>')


def knob(svg, ident, size, fill, ring, shadow_alpha):
    c = size / 2
    body = (f'<circle cx="{c}" cy="{c + 0.8}" r="{c - 1}" fill="#000" fill-opacity="{shadow_alpha:.3f}"/>'
            f'<circle cx="{c}" cy="{c}" r="{c - 1.5}" {paint(fill)}/>'
            f'<circle cx="{c}" cy="{c}" r="{c - 1.5}" fill="none" stroke-width="1" {paint(ring, "stroke")}/>')
    svg.add(ident, size, size, body)


def build(th, name):
    c = th.c
    dark = th.dark
    sh = th.shape
    rc = sh["control"]          # 10
    rs = sh["small"]            # 6
    rk = sh["container"]        # 14
    text, text2, text3 = c["text"], c["text2"], c["text3"]
    ink = WHITE if dark else Color(0, 0, 0)
    a = (lambda x: ink.with_alpha(x))
    fill, fill_h, fill_p, fill_t = a(.06 if not dark else .09), a(.10 if not dark else .14), a(.15 if not dark else .20), a(.13 if not dark else .18)
    hover, active = c["hover"], c["active"]
    disabled_txt = text.with_alpha(.38)
    accent, on_accent = c["accent"], c["onAccent"]
    stroke, stroke_s = c["stroke"], c["strokeStrong"]
    focus = accent.with_alpha(.55 if not dark else .65)
    float_bg = c["float"].with_alpha(.86 if not dark else .82)
    svg = Svg()

    def states(fn):
        for st in STATES:
            fn(st)

    # buttons (flat-tinted): btn frame + button interior share colors
    bfill = {"normal": fill, "focused": fill_h, "pressed": fill_p, "toggled": fill_t, "disabled": a(.035)}

    def btn(st):
        rr_frame(svg, f"btn-{st}", rc, rc, bfill[st], interior=f"button-{st}")
    states(btn)
    rr_frame(svg, "btn-default", rc, rc, accent.with_alpha(.16 if not dark else .26), interior="button-default")
    rr_frame(svg, "btn-focus", rc, rc, None, focus, 2)
    svg.add("button-default-indicator", 4, 4)

    # toolbar / flat tool buttons: transparent until hovered
    tfill = {"normal": None, "focused": hover, "pressed": active, "toggled": fill_t, "disabled": None}
    for st in STATES:
        rr_frame(svg, f"tbtn-{st}", rc, rc, tfill[st], interior=f"tbutton-{st}")
    rr_frame(svg, "tbtn-focus", rc, rc, None, focus, 2)

    # spin indicators (inline, flat)
    for st in STATES:
        rr_frame(svg, f"ispin-{st}", 6, 6, tfill[st], interior=f"ispinbtn-{st}")

    # line edit (filled) + focused ring
    lefill = {"normal": fill, "focused": fill, "pressed": fill, "toggled": fill, "disabled": a(.035)}
    for st in STATES:
        if st == "focused":
            rr_frame(svg, f"le-{st}", rc, rc, fill, accent, 2, interior=f"lineedit-{st}")
        else:
            rr_frame(svg, f"le-{st}", rc, rc, lefill[st], interior=f"lineedit-{st}")

    # combo (same as button)
    for st in STATES:
        rr_frame(svg, f"combo-{st}", rc, rc, bfill[st], interior=f"combobox-{st}")
    rr_frame(svg, "combo-focus", rc, rc, None, focus, 2)

    # tabs: pill
    tabfill = {"normal": None, "focused": hover, "pressed": active, "toggled": a(.08 if not dark else .12), "disabled": None}
    for st in STATES:
        rr_frame(svg, f"tab-{st}", 8, 8, tabfill[st], interior=f"tab-{st}")
    rr_frame(svg, "tab-focus", 8, 8, None, focus, 2)
    for st in STATES:
        rr_frame(svg, f"tabbar-{st}", 4, 4, None, interior=f"tabbarframe-{st}")
        rr_frame(svg, f"tabframe-{st}", rk, rk, None, stroke, 1, interior=f"tabframe-int-{st}")

    # generic frames and group boxes
    for st in STATES:
        rr_frame(svg, f"common-{st}", 2, 2, None, stroke, 1, interior=f"common-int-{st}")
        rr_frame(svg, f"group-{st}", rk, rk, c["surface"] if not dark else c["surface"], stroke, 1, interior=f"groupbox-{st}")

    # item views: container selection
    ivfill = {"normal": None, "focused": hover, "pressed": c["container"], "toggled": c["container"], "disabled": None}
    for st in STATES:
        rr_frame(svg, f"itemview-{st}", rs, rs, ivfill[st], interior=f"itemview-{st}")
        rr_frame(svg, f"itemview-{st}-inactive", rs, rs,
                 ivfill[st] if st in ("normal", "focused", "disabled") else a(.08), interior=f"itemview-{st}-inactive")

    # menus and tooltips (glass-ish, with shadow)
    menu_F, menu_D = 8, 14
    shadow_a = .20 if not dark else .45
    shadow_frame(svg, "menu", menu_F, menu_D, 12 if menu_F >= 12 else menu_F, float_bg, stroke, shadow_a)
    # plain frame only used for opaque menus (e.g. KWin's own menus, which Kvantum treats as uncomposited)
    for st in STATES:
        rr_frame(svg, f"menu-{st}", menu_F, 0, float_bg.over(c["canvas"]), stroke, 1)
        svg.add(f"menu-{st}", 8, 8, f'<rect width="8" height="8" {paint(float_bg)}/>')
    mi = {"normal": None, "focused": hover, "pressed": active, "toggled": hover, "disabled": None}
    for st in STATES:
        rr_frame(svg, f"menuitem-{st}", rs, rs, mi[st], interior=f"menuitem-{st}")
    tip_F, tip_D = 6, 8
    tip_bg = c["float"].with_alpha(.92)
    shadow_frame(svg, "tooltip", tip_F, tip_D, tip_F, tip_bg, stroke, shadow_a * .8, dy=2)
    for st in STATES:
        rr_frame(svg, f"tooltip-{st}", tip_F, 0, tip_bg.over(c["canvas"]), stroke, 1)
        svg.add(f"tooltip-{st}", 8, 8, f'<rect width="8" height="8" {paint(tip_bg)}/>')

    # menubar / toolbar backgrounds: flat
    for st in STATES:
        line_frame(svg, f"menubar-{st}", 1, None, ())
        flat_interior(svg, f"menubar-{st}", None)
        rr_frame(svg, f"menubaritem-{st}", rs, rs, mi[st], interior=f"menubaritem-int-{st}")
        line_frame(svg, f"toolbar-{st}", 1, None, ())
        flat_interior(svg, f"toolbar-{st}", None)
        line_frame(svg, f"statusbar-{st}", 1, None, ())

    # header sections: flat with a hairline
    for st in STATES:
        line_frame(svg, f"header-{st}", 1, stroke, ("bottom",))
        flat_interior(svg, f"header-{st}", hover if st == "focused" else None)
    svg.add("header-separator", 1, 8, f'<rect width="1" height="8" {paint(stroke)}/>')

    # scrollbars: thin overlay pills
    for st in STATES:
        col = {"normal": a(.32), "focused": a(.48), "pressed": a(.58), "toggled": a(.48), "disabled": a(.15)}[st]
        rr_frame(svg, f"scrollbarslider-{st}", 5, 3, col, inset=2)
        flat_interior(svg, f"scrollbarslider-int-{st}", None)
        rr_frame(svg, f"scrollgroove-{st}", 5, 3, None)
        flat_interior(svg, f"scrollgroove-int-{st}", None)

    # slider groove + progress (thin), knob
    for st in STATES:
        gcol = a(.12 if not dark else .18)
        rr_frame(svg, f"slider-{st}", 2, 2, accent if st == "toggled" else gcol, interior=f"slider-{st}")
        rr_frame(svg, f"progress-{st}", 3, 3, a(.10 if not dark else .16), interior=f"progress-{st}")
        rr_frame(svg, f"progresspat-{st}", 3, 3, accent, interior=f"progress-pattern-{st}")
    knob_fill = WHITE if not dark else th.ok(.92)
    for st in STATES:
        ring = a(.18) if not dark else Color(0, 0, 0, .35)
        kf = knob_fill if st != "disabled" else knob_fill.mix(c["canvas"], .5)
        knob(svg, f"slidercursor-{st}", 20, kf, ring, .14 if not dark else .35)
        knob(svg, f"slidercursor-tickless-{st}", 20, kf, ring, .14 if not dark else .35)
    svg.add("slider-tick", 1, 4, f'<rect width="1" height="4" {paint(stroke_s)}/>')

    # splitter, focus, dock
    for st in STATES:
        flat_interior(svg, f"splitter-{st}", None)
        svg.add(f"splitter-grip-{st}", 8, 8)
        rr_frame(svg, f"dock-{st}", 1, 0, None, interior=f"dock-{st}")
    rr_frame(svg, "focus", 3, rc, None, focus, 2)

    # checkboxes and radios
    cb_border = {"normal": a(.30), "focused": a(.45), "pressed": a(.55), "toggled": a(.45), "disabled": a(.15)}
    acc_state = {"normal": accent, "focused": c["accentHover"], "pressed": c["accentPressed"], "toggled": c["accentHover"],
                 "disabled": accent.with_alpha(.4)}
    for prefix, box, size in (("", 20, 18), ("menu-", 18, 16), ("item-", 18, 16)):
        for st in STATES:
            check_el(svg, f"{prefix}checkbox-{st}", "box", box, size, None, None, cb_border[st], None)
            check_el(svg, f"{prefix}checkbox-checked-{st}", "box-on", box, size, acc_state[st], on_accent, None, None)
            check_el(svg, f"{prefix}checkbox-tristate-{st}", "box-tri", box, size, acc_state[st], on_accent, None, None)
            if prefix != "item-":
                check_el(svg, f"{prefix}radio-{st}", "radio", box, size, None, None, cb_border[st], None)
                check_el(svg, f"{prefix}radio-checked-{st}", "radio-on", box, size, acc_state[st], on_accent, None, None)

    # indicators
    icol = {"normal": text2, "focused": text, "pressed": text, "toggled": text, "disabled": disabled_txt}
    for st in STATES:
        for dr in ("up", "down", "left", "right"):
            chevron(svg, f"arrow-{dr}-{st}", dr, icol[st])
            chevron(svg, f"flat-arrow-{dr}-{st}", dr, icol[st])
            chevron(svg, f"iarrow-{dr}-{st}", dr, icol[st])
        glyph(svg, f"iarrow-plus-{st}", "plus", icol[st])
        glyph(svg, f"iarrow-minus-{st}", "minus", icol[st])
        chevron(svg, f"tree-plus-{st}", "right", icol[st])
        chevron(svg, f"tree-minus-{st}", "down", icol[st])
        chevron(svg, f"menuitem-right-{st}", "right", icol[st])
        chevron(svg, f"menuitem-left-{st}", "left", icol[st])
        glyph(svg, f"tab-close-{st}", "close", icol[st], sw=1.4)
        for k, g in (("close", "close"), ("maximize", "max"), ("minimize", "min"), ("restore", "restore"), ("menu", "menu"), ("shade", "min")):
            glyph(svg, f"mdi-{k}-{st}", g, icol[st])
        svg.add(f"resize-grip-{st}", 8, 8)
        svg.add(f"iarrow-separator-{st}", 1, 8)
        svg.add(f"arrow-separator-{st}", 1, 8)
    for k in ("toolbar-handle", "toolbar-handle-inactive", "tab-tear"):
        svg.add(k, 4, 4)
    return svg.text(), kvconfig(th, name, menu_F, menu_D, tip_F, tip_D)


def kvconfig(th, name, menu_F, menu_D, tip_F, tip_D):
    c = th.c
    dark = th.dark
    d = th.density
    rc = th.shape["control"]
    rk = th.shape["container"]
    text, text2 = c["text"], c["text2"]
    disabled = text.with_alpha(.38).over(c["canvas"])
    H = d["control"]

    def col(x):
        return x.hexa if x.a < .999 else x.hexs

    general = {
        "author": "oneDesign", "comment": f"oneDesign {th.lang['name']} ({th.mode})",
        "x11drag": "menubar_and_primary_toolbar", "alt_mnemonic": "true", "left_tabs": "false",
        "attach_active_tab": "false", "mirror_doc_tabs": "false", "group_toolbar_buttons": "false",
        "toolbar_item_spacing": "2", "toolbar_interior_spacing": "4", "spread_progressbar": "true",
        "spread_menuitems": "false", "composite": "true", "menu_shadow_depth": menu_D,
        "tooltip_shadow_depth": tip_D, "menu_blur_radius": 8, "tooltip_blur_radius": 6,
        "scroll_width": 10, "scroll_arrows": "false", "scroll_min_extent": 40, "transient_scrollbar": "true",
        "transient_groove": "true", "slider_width": 4, "slider_handle_width": 20, "slider_handle_length": 20,
        "tickless_slider_handle_size": 20, "center_toolbar_handle": "true", "check_size": 20,
        "textless_progressbar": "false", "progressbar_thickness": 6, "menubar_mouse_tracking": "true",
        "toolbutton_style": 0, "click_behavior": 0, "translucent_windows": "false", "blurring": "false",
        "popup_blurring": "true", "vertical_spin_indicators": "false", "inline_spin_indicators": "true",
        "inline_spin_separator": "false", "spin_button_width": 28, "fill_rubberband": "false",
        "merge_menubar_with_toolbar": "false", "small_icon_size": 16, "large_icon_size": 32,
        "button_icon_size": 16, "toolbar_icon_size": 16, "combo_as_lineedit": "false",
        "square_combo_button": "false", "combo_menu": "true", "hide_combo_checkboxes": "true",
        "combo_focus_rect": "false", "spread_header": "true", "layout_spacing": 6, "layout_margin": 12,
        "tooltip_delay": -1, "submenu_overlap": 0, "submenu_delay": 200, "animate_states": "true",
        "tree_branch_line": "false", "contrast": "1.00", "dialog_button_layout": 2,
        "groupbox_top_label": "true", "intensity": "1.00", "joined_inactive_tabs": "false",
        "no_inactiveness": "true", "no_window_pattern": "true", "reduce_menu_opacity": 0,
        "reduce_window_opacity": 0, "respect_DE": "true", "saturation": "1.00", "scrollable_menu": "true",
        "scrollbar_in_view": "false", "menu_separator_height": 9, "splitter_width": 1,
        "center_normal_tabs": "false", "center_doc_tabs": "false", "no_active_tab_separator": "true",
        "bold_active_tab": "false", "slim_toolbars": "false", "toolbar_separator_thickness": 1,
        "dark_titlebar": "true" if dark else "false",
    }
    colors = {
        "window.color": col(c["canvas"]), "inactive.window.color": col(c["canvas"]),
        "base.color": col(c["surface"]), "inactive.base.color": col(c["surface"]),
        "alt.base.color": col(c["surfaceAlt"]), "inactive.alt.base.color": col(c["surfaceAlt"]),
        "button.color": col(c["fill"].over(c["canvas"])),
        "light.color": col(th.ok(.99 if not dark else .40)), "mid.light.color": col(th.ok(.93 if not dark else .34)),
        "dark.color": col(th.ok(.70 if not dark else .12)), "mid.color": col(th.ok(.82 if not dark else .20)),
        "shadow.color": "#00000060", "highlight.color": col(c["accent"]), "inactive.highlight.color": col(c["accent"]),
        "text.color": col(text), "inactive.text.color": col(text), "window.text.color": col(text),
        "inactive.window.text.color": col(text), "button.text.color": col(text), "disabled.text.color": col(disabled),
        "tooltip.base.color": col(c["float"]), "tooltip.text.color": col(text),
        "highlight.text.color": col(c["onAccent"]), "link.color": col(c["accentText"]),
        "link.visited.color": col(th.ok(.74 if dark else .5, .14, 310)),
        "progress.indicator.text.color": col(text), "progress.inactive.indicator.text.color": col(text),
        "placeholder.text.color": col(c["text3"]),
    }
    hacks = {
        "transparent_ktitle_label": "true", "transparent_dolphin_view": "false", "transparent_pcmanfm_sidepane": "true",
        "blur_translucent": "true", "transparent_menutitle": "true", "transparent_arrow_button": "true",
        "respect_darkness": "true", "force_size_grip": "false", "iconless_pushbutton": "false",
        "iconless_menu": "false", "disabled_icon_opacity": 60, "normal_default_pushbutton": "false",
        "single_top_toolbar": "true", "tint_on_mouseover": 0, "no_selection_tint": "true",
        "middle_click_scroll": "false", "kinetic_scrolling": "false", "style_vertical_toolbars": "false",
    }
    tc = {"text.normal.color": col(text), "text.normal.inactive.color": col(text),
          "text.focus.color": col(text), "text.press.color": col(text), "text.toggle.color": col(text),
          "text.toggle.inactive.color": col(text)}
    pad = d["padX"] - rc  # text margin on top of the frame
    sections = {}

    def sec(n, **kv):
        sections[n] = kv

    sec("PanelButtonCommand", frame="true", **{"frame.element": "btn", "frame.top": rc, "frame.bottom": rc,
        "frame.left": rc, "frame.right": rc, "interior": "true", "interior.element": "button",
        "indicator.element": "arrow", "indicator.size": 16, "focusFrame": "true",
        "text.margin": "true", "text.margin.top": 0, "text.margin.bottom": 0, "text.margin.left": pad,
        "text.margin.right": pad, "text.iconspacing": 6, "text.shadow": "false", "text.bold": "false",
        "text.boldness": 2, "min_width": "+0.3font", "min_height": H, "frame.expansion": 0, **tc})
    sec("PanelButtonTool", inherits="PanelButtonCommand")
    sec("ToolbarButton", inherits="PanelButtonCommand", **{"frame.element": "tbtn", "interior.element": "tbutton",
        "text.margin.left": 2, "text.margin.right": 2, "min_width": H - 2 * rc, "min_height": H - 2})
    sec("ToolbarComboBox", inherits="ComboBox")
    sec("ToolbarLineEdit", inherits="LineEdit")
    sec("ComboBox", inherits="PanelButtonCommand", **{"frame.element": "combo", "interior.element": "combobox",
        "indicator.element": "arrow-down"})
    sec("DropDownButton", inherits="PanelButtonCommand", **{"indicator.element": "arrow-down", "indicator.size": 16})
    sec("IndicatorArrow", **{"indicator.element": "arrow", "indicator.size": 16})
    sec("IndicatorSpinBox", inherits="PanelButtonCommand", **{"frame.element": "ispin", "interior.element": "ispinbtn",
        "frame.top": 6, "frame.bottom": 6, "frame.left": 6, "frame.right": 6, "focusFrame": "false",
        "indicator.element": "iarrow", "indicator.size": 16})
    sec("LineEdit", inherits="PanelButtonCommand", **{"frame.element": "le", "interior.element": "lineedit",
        "focusFrame": "false", "text.margin.left": pad, "text.margin.right": pad})
    sec("RadioButton", inherits="PanelButtonCommand", **{"frame": "false", "interior.element": "radio",
        "text.margin.top": 2, "text.margin.bottom": 2, "text.margin.left": 4, "text.margin.right": 4,
        "min_height": 24, "focusFrame": "false"})
    sec("CheckBox", inherits="RadioButton", **{"interior.element": "checkbox"})
    sec("Focus", frame="true", **{"frame.element": "focus", "frame.top": 3, "frame.bottom": 3, "frame.left": 3,
        "frame.right": 3, "frame.patternsize": 0})
    sec("GenericFrame", frame="true", interior="false", **{"frame.element": "common", "interior.element": "common-int",
        "frame.top": 2, "frame.bottom": 2, "frame.left": 2, "frame.right": 2})
    sec("GroupBox", inherits="GenericFrame", **{"frame.element": "group", "interior": "true",
        "interior.element": "groupbox", "frame.top": rk, "frame.bottom": rk, "frame.left": rk, "frame.right": rk,
        "text.margin": 0, "text.bold": "true", **tc})
    sec("TabFrame", inherits="GenericFrame", **{"frame.element": "tabframe", "interior.element": "tabframe-int",
        "frame.top": rk, "frame.bottom": rk, "frame.left": rk, "frame.right": rk})
    sec("TabBarFrame", inherits="GenericFrame", **{"frame": "false", "interior": "false",
        "frame.element": "tabbar", "interior.element": "tabbarframe", "frame.top": 4, "frame.bottom": 4,
        "frame.left": 4, "frame.right": 4})
    sec("Tab", inherits="PanelButtonCommand", **{"frame.element": "tab", "interior.element": "tab",
        "frame.top": 8, "frame.bottom": 8, "frame.left": 8, "frame.right": 8, "text.margin.left": 8,
        "text.margin.right": 8, "text.margin.top": 0, "text.margin.bottom": 0, "indicator.element": "tab",
        "indicator.size": 16, "min_height": 32, "min_width": "4font",
        "text.normal.color": col(text2), "text.focus.color": col(text), "text.toggle.color": col(text)})
    sec("ToolboxTab", inherits="Tab")
    sec("TreeExpander", inherits="PanelButtonCommand", **{"frame": "false", "interior": "false",
        "indicator.element": "tree", "indicator.size": 16})
    sec("HeaderSection", inherits="PanelButtonCommand", **{"frame.element": "header", "interior.element": "header",
        "frame.top": 1, "frame.bottom": 1, "frame.left": 1, "frame.right": 1, "text.margin.left": 8,
        "text.margin.right": 8, "text.margin.top": 4, "text.margin.bottom": 4, "focusFrame": "false",
        "min_height": 30, "text.normal.color": col(text2), "text.focus.color": col(text), "text.press.color": col(text),
        "text.toggle.color": col(text), "text.bold": "false"})
    sec("SizeGrip", **{"indicator.element": "resize-grip"})
    sec("Toolbar", inherits="PanelButtonCommand", **{"frame.element": "toolbar", "interior.element": "toolbar",
        "indicator.element": "toolbar", "indicator.size": 5, "frame.top": 0, "frame.bottom": 0,
        "frame.left": 0, "frame.right": 0, "text.margin": 0, "focusFrame": "false"})
    sec("MenuBar", inherits="Toolbar", **{"frame.element": "menubar", "interior.element": "menubar"})
    sec("MenuBarItem", inherits="PanelButtonCommand", **{"frame.element": "menubaritem",
        "interior.element": "menubaritem-int", "frame.top": 6, "frame.bottom": 6, "frame.left": 6,
        "frame.right": 6, "text.margin.left": 4, "text.margin.right": 4, "text.margin.top": 0,
        "text.margin.bottom": 0, "min_height": 28, "min_width": 0, "focusFrame": "false"})
    sec("Menu", inherits="PanelButtonCommand", **{"frame.element": "menu", "interior.element": "menu",
        "frame.top": menu_F, "frame.bottom": menu_F, "frame.left": menu_F, "frame.right": menu_F,
        "focusFrame": "false"})
    sec("MenuItem", inherits="PanelButtonCommand", **{"frame.element": "menuitem", "interior.element": "menuitem",
        "indicator.element": "menuitem", "indicator.size": 16, "frame.top": 6, "frame.bottom": 6,
        "frame.left": 6, "frame.right": 6, "text.margin.left": 4, "text.margin.right": 4,
        "text.margin.top": 0, "text.margin.bottom": 0, "min_height": 32, "min_width": 0, "focusFrame": "false"})
    sec("ToolTip", inherits="GenericFrame", **{"frame.element": "tooltip", "interior": "true",
        "interior.element": "tooltip", "frame.top": tip_F, "frame.bottom": tip_F, "frame.left": tip_F,
        "frame.right": tip_F, "text.margin.left": 4, "text.margin.right": 4, "text.margin.top": 2,
        "text.margin.bottom": 2, **tc})
    sec("StatusBar", inherits="GenericFrame", **{"frame": "false", "interior": "false"})
    sec("ItemView", inherits="PanelButtonCommand", **{"frame.element": "itemview", "interior.element": "itemview",
        "frame.top": 6, "frame.bottom": 6, "frame.left": 6, "frame.right": 6, "text.margin.top": 0,
        "text.margin.bottom": 0, "text.margin.left": 2, "text.margin.right": 2, "min_height": 30,
        "focusFrame": "false", "text.toggle.color": col(c["onContainer"]), "text.press.color": col(c["onContainer"]),
        "text.toggle.inactive.color": col(text)})
    sec("Scrollbar", inherits="PanelButtonCommand", **{"indicator.element": "arrow", "indicator.size": 10})
    sec("ScrollbarGroove", inherits="PanelButtonCommand", **{"frame": "false", "interior": "false",
        "frame.element": "scrollgroove", "interior.element": "scrollgroove-int"})
    sec("ScrollbarSlider", inherits="PanelButtonCommand", **{"frame.element": "scrollbarslider",
        "interior": "false", "interior.element": "scrollbarslider-int", "frame.top": 5, "frame.bottom": 5,
        "frame.left": 5, "frame.right": 5, "focusFrame": "false", "indicator.size": 0})
    sec("ScrollbarTransientSlider", inherits="ScrollbarSlider")
    sec("Slider", inherits="PanelButtonCommand", **{"frame.element": "slider", "interior.element": "slider",
        "frame.top": 2, "frame.bottom": 2, "frame.left": 2, "frame.right": 2, "focusFrame": "false"})
    sec("SliderCursor", inherits="PanelButtonCommand", **{"frame": "false", "interior.element": "slidercursor",
        "focusFrame": "false"})
    sec("Progressbar", inherits="PanelButtonCommand", **{"frame.element": "progress", "interior.element": "progress",
        "frame.top": 3, "frame.bottom": 3, "frame.left": 3, "frame.right": 3, "text.margin": 0,
        "focusFrame": "false", "text.bold": "false", "frame.expansion": 0})
    sec("ProgressbarContents", inherits="Progressbar", **{"frame.element": "progresspat",
        "interior.element": "progress-pattern"})
    sec("Splitter", **{"interior.element": "splitter", "frame": "false", "indicator.element": "splitter-grip",
        "indicator.size": 8})
    sec("Dock", inherits="PanelButtonCommand", **{"frame.element": "dock", "interior.element": "dock",
        "frame.top": 1, "frame.bottom": 1, "frame.left": 1, "frame.right": 1, "interior": "false", "frame": "false"})
    sec("DockTitle", inherits="PanelButtonCommand", **{"frame": "false", "interior": "false", "text.bold": "true",
        "text.margin.top": 4, "text.margin.bottom": 4, "focusFrame": "false"})
    sec("TitleBar", inherits="PanelButtonCommand", **{"frame": "false", "interior": "false",
        "indicator.element": "mdi", "indicator.size": 16, "text.bold": "true"})
    sec("Window", **{"interior": "false", "frame": "false"})
    sec("Dialog", inherits="Window")

    out = [f"[%General]"] + [f"{k}={v}" for k, v in general.items()]
    out += ["", "[GeneralColors]"] + [f"{k}={v}" for k, v in colors.items()]
    out += ["", "[Hacks]"] + [f"{k}={v}" for k, v in hacks.items()]
    for n, kv in sections.items():
        out += ["", f"[{n}]"] + [f"{k}={v}" for k, v in kv.items()]
    return "\n".join(out) + "\n"
