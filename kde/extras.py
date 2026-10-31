"""Wallpapers, Konsole schemes, GTK overrides, fonts and login manager config."""
import io
import json

from PIL import Image

from onetokens import ROOT, WALLS

WALL_SRC = ROOT / "prototypes" / "assets" / "wallpapers"
FONT_SRC = {
    "InterVariable.ttf": ROOT / "reference" / "fonts" / "inter" / "InterVariable.ttf",
    "InterVariable-Italic.ttf": ROOT / "reference" / "fonts" / "inter" / "InterVariable-Italic.ttf",
    "GeistMono[wght].ttf": ROOT / "reference" / "fonts" / "geist" / "GeistMono[wght].ttf",
}


def _jpg(path):
    im = Image.open(path).convert("RGB")
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=93, optimize=True, progressive=True)
    return buf.getvalue()


def wallpapers():
    """Returns {relative path under share/wallpapers: bytes|str}."""
    out = {}
    for wall in WALLS:
        pkg = f"One-{wall.capitalize()}"
        light, dark = WALL_SRC / f"{wall}-light.webp", WALL_SRC / f"{wall}-dark.webp"
        w, h = Image.open(light).size
        out[f"{pkg}/contents/images/{w}x{h}.jpg"] = _jpg(light)
        out[f"{pkg}/contents/images_dark/{w}x{h}.jpg"] = _jpg(dark)
        thumb = Image.open(light).convert("RGB").resize((400, 250), Image.LANCZOS)
        buf = io.BytesIO()
        thumb.save(buf, "JPEG", quality=88)
        out[f"{pkg}/contents/screenshot.jpg"] = buf.getvalue()
        out[f"{pkg}/metadata.json"] = json.dumps({
            "KPlugin": {"Authors": [{"Name": "oneDesign"}], "Id": pkg, "License": "CC-BY-SA-4.0",
                        "Name": f"One {wall.capitalize()}"}
        }, indent=4) + "\n"
    return out


def konsole(th, name):
    a = th.ansi()
    rgb = lambda c: ",".join(str(v) for v in c.rgb255)
    order = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]
    lines = [f"[Background]\nColor={rgb(a['bg'])}\n", f"[BackgroundIntense]\nColor={rgb(a['bg'])}\n",
             f"[BackgroundFaint]\nColor={rgb(a['bg'])}\n"]
    for i, k in enumerate(order):
        bright = "bright" + k.capitalize()
        lines.append(f"[Color{i}]\nColor={rgb(a[k])}\n")
        lines.append(f"[Color{i}Intense]\nColor={rgb(a[bright])}\n")
        lines.append(f"[Color{i}Faint]\nColor={rgb(a[k].mix(a['bg'], 0.35))}\n")
    lines += [f"[Foreground]\nColor={rgb(a['fg'])}\n", f"[ForegroundIntense]\nColor={rgb(a['fg'])}\nBold=true\n",
              f"[ForegroundFaint]\nColor={rgb(a['fg'].mix(a['bg'], 0.4))}\n",
              f"[General]\nAnchor=0.5,0.5\nBlur=false\nColorRandomization=false\n"
              f"Description={name.replace('One', 'One ').strip()}\nFillStyle=Tile\nOpacity=1\nWallpaper=\n"]
    return "\n".join(lines)


def konsole_profile(scheme):
    return f"""[Appearance]
ColorScheme={scheme}
Font=Geist Mono,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
LineSpacing=2

[General]
Name=One
Parent=FALLBACK/
TerminalMargin=14
TerminalCenter=true

[Scrolling]
ScrollBarPosition=2
"""


def _gtk_named(th):
    c = th.c
    return {
        "accent_bg_color": c["accent"], "accent_fg_color": c["onAccent"], "accent_color": c["accentText"],
        "destructive_bg_color": c["danger"], "destructive_fg_color": c["onAccent"],
        "destructive_color": c["danger"], "success_color": c["success"], "warning_color": c["warning"],
        "error_color": c["danger"],
        "window_bg_color": c["canvas"], "window_fg_color": c["text"],
        "view_bg_color": c["surface"], "view_fg_color": c["text"],
        "headerbar_bg_color": c["headerbar"], "headerbar_fg_color": c["text"],
        "headerbar_backdrop_color": c["headerbar"], "headerbar_border_color": c["text"],
        "headerbar_shade_color": c["stroke"],
        "sidebar_bg_color": c["sidebar"], "sidebar_fg_color": c["text"],
        "sidebar_backdrop_color": c["sidebar"], "sidebar_border_color": c["stroke"],
        "secondary_sidebar_bg_color": c["surfaceAlt"], "secondary_sidebar_fg_color": c["text"],
        "card_bg_color": c["surface"] if not th.dark else c["surfaceAlt"], "card_fg_color": c["text"],
        "card_shade_color": c["stroke"],
        "dialog_bg_color": c["float"], "dialog_fg_color": c["text"],
        "popover_bg_color": c["float"], "popover_fg_color": c["text"], "popover_shade_color": c["stroke"],
        "thumbnail_bg_color": c["surface"], "thumbnail_fg_color": c["text"],
    }


def _gtk_vars(th, indent):
    return "\n".join(f"{indent}--{k.replace('_', '-')}: {v.css};" for k, v in _gtk_named(th).items())


def gtk_css(light, dark, version):
    """Appended to ~/.config/gtk-{3,4}.0/gtk.css after KDE's colors.css import.

    GTK 4 gets the One colors for both modes, switched by prefers-color-scheme so it
    follows KDE's light/dark switching. GTK 3 has no media queries, so it only gets
    shape and keeps the colors KDE generates from the active scheme.
    """
    sh = light.shape
    colors = ""
    if version == 4:
        colors = f""":root {{
{_gtk_vars(light, "  ")}
  --window-radius: {sh['window']}px;
}}
@media (prefers-color-scheme: dark) {{
  :root {{
{_gtk_vars(dark, "    ")}
  }}
}}
"""
    return f"""/* oneDesign:begin */
{colors}button, entry, spinbutton, dropdown > button, combobox > box > button {{ border-radius: {sh['control']}px; }}
.card, list.boxed-list, .boxed-list, preferencesgroup list {{ border-radius: {sh['container']}px; }}
popover > contents, popover.menu > contents {{ border-radius: {sh['container']}px; }}
popover modelbutton, popover.menu modelbutton {{ border-radius: {sh['small']}px; }}
window.csd, window.csd > .titlebar, dialog.csd {{ border-radius: {sh['window']}px {sh['window']}px 0 0; }}
/* oneDesign:end */
"""


def plasmalogin_conf(wall="lagoon"):
    pkg = f"One-{wall.capitalize()}"
    w, h = Image.open(WALL_SRC / f"{wall}-light.webp").size
    return f"""# oneDesign greeter wallpaper. Install as /etc/plasmalogin.conf.d/one.conf
[Greeter]
WallpaperPluginId=org.kde.image

[Greeter][Wallpaper][org.kde.image][General]
Image=file:///usr/share/wallpapers/{pkg}/contents/images/{w}x{h}.jpg
"""


def fonts():
    return {name: p.read_bytes() for name, p in FONT_SRC.items() if p.exists()}


def font_settings():
    """kdeglobals / kwinrc font keys (Qt 6 font strings)."""
    f = lambda fam, size, weight=400: f"{fam},{size},-1,5,{weight},0,0,0,0,0,0,0,0,0,0,1"
    return {
        ("kdeglobals", "General", "font"): f("Inter Variable", 10),
        ("kdeglobals", "General", "menuFont"): f("Inter Variable", 10),
        ("kdeglobals", "General", "toolBarFont"): f("Inter Variable", 10),
        ("kdeglobals", "General", "smallestReadableFont"): f("Inter Variable", 8),
        ("kdeglobals", "General", "fixed"): f("Geist Mono", 10),
        ("kdeglobals", "WM", "activeFont"): f("Inter Variable", 10, 600),
    }
