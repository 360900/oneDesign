"""SDDM greeter theme (Qt 6) matching the prototype login scene."""
import io
import re
from pathlib import Path

from PIL import Image, ImageOps

from onetokens import BLACK, ROOT, WHITE

HERE = Path(__file__).resolve().parent
ICON_SRC = ROOT / "reference" / "icons" / "adwaita"
ICONS = ("go-next", "pan-down", "computer", "system-shutdown", "list-add")
WALL_SRC = ROOT / "prototypes" / "assets" / "wallpapers"
FONT = ROOT / "reference" / "fonts" / "inter" / "InterVariable.ttf"

METADATA = """[SddmGreeterTheme]
Name=One
Description=oneDesign login screen
Author=oneDesign
License=GPL-3.0-or-later
Type=sddm-theme
Version=1.0
Website=
Screenshot=preview.jpg
MainScript=Main.qml
ConfigFile=theme.conf
Theme-Id=one
Theme-API=2.0
QtVersion=6
"""


def palette(th):
    c, d = th.c, th.dark
    return {
        "Background": f"background-{th.mode}.jpg",
        "Veil": BLACK.with_alpha(.28) if d else WHITE.with_alpha(.06),
        "OnWallpaper": WHITE,
        "Card": c["float"].with_alpha(.9 if d else .94),
        "Field": c["surface"] if not d else c["surfaceAlt"],
        "Glass": c["glass"],
        "Shadow": BLACK.with_alpha(.5 if d else .26),
        "Stroke": c["stroke"],
        "StrokeStrong": c["strokeStrong"],
        "Hover": c["hover"],
        "Active": c["active"],
        "Text": c["text"],
        "Text2": c["text2"],
        "Text3": c["text3"],
        "Accent": c["accent"],
        "AccentHover": c["accentHover"],
        "AccentPressed": c["accentPressed"],
        "OnAccent": c["onAccent"],
        "Danger": c["danger"],
        "AvatarA": th.ok(.8, .1, th.hue - 25),
        "AvatarB": th.ok(.74, .12, th.hue + 40),
        "AvatarBody": th.ok(.4, .09, th.hue),
        "AvatarHead": th.ok(.88, .05, 60),
    }


def _qml_color(v):
    return v if isinstance(v, str) else (v.argb if v.a < 1 else v.hexs)


def theme_conf(themes, default_mode="light"):
    lines = ["[General]", f"Mode={default_mode}", "Scale=1", f"Radius={themes[0].shape['window'] + 4}",
             "DateFormat=dddd, d MMMM", "TimeFormat=HH:mm", ""]
    for th in themes:
        for k, v in palette(th).items():
            lines.append(f"{th.mode}_{k}={_qml_color(v)}")
        lines.append("")
    return "\n".join(lines)


def _icon(name, color):
    svg = (ICON_SRC / f"{name}-symbolic.svg").read_text()
    return re.sub(r'fill="#(2e3436|222)"', f'fill="{color.hexs}"', svg)


def _jpg(path, size=(1920, 1200)):
    im = Image.open(path).convert("RGB")
    im = ImageOps.fit(im, size, Image.LANCZOS) if im.size[0] > size[0] else im
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=90, optimize=True, progressive=True)
    return buf.getvalue()


def build(themes, wall="wave"):
    """themes: (light, dark) resolved themes. Returns {relpath: str|bytes}."""
    out = {
        "Main.qml": (HERE / "sddm" / "Main.qml").read_text(),
        "metadata.desktop": METADATA,
        "theme.conf": theme_conf(themes),
        "fonts/InterVariable.ttf": FONT.read_bytes(),
    }
    for th in themes:
        out[f"background-{th.mode}.jpg"] = _jpg(WALL_SRC / f"{wall}-{th.mode}.webp")
        for name in ICONS:
            out[f"icons/{th.mode}/{name}.svg"] = _icon(name, th.c["text"])
            out[f"icons/{th.mode}/{name}-on.svg"] = _icon(name, th.c["onAccent"])
    preview = HERE / "previews" / "sddm.jpg"
    if preview.exists():
        out["preview.jpg"] = preview.read_bytes()
    return out
