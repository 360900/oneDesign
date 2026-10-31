#!/usr/bin/env python3
"""Build the One KDE theme into build/kde/ (install layout: share/, config/, etc/, gtk/)."""
import argparse
import json
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE.parent / "tools"), str(HERE)]

from onetokens import ROOT, WALLS, resolve  # noqa: E402
import aurorae  # noqa: E402
import colors  # noqa: E402
import extras  # noqa: E402
import icons  # noqa: E402
import kvantum  # noqa: E402
import lnf  # noqa: E402
import plasma  # noqa: E402
import sddm  # noqa: E402

MODES = (("light", "OneLight", "One"), ("dark", "OneDark", "OneDark"))


def write(out, rel, data):
    p = out / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(data, bytes):
        p.write_bytes(data)
    else:
        p.write_text(data)


def icon_theme(dark):
    return "One-Dark" if dark else "One"


def previews(mode):
    src = HERE / "previews" / f"{mode}.jpg"
    if not src.exists():
        return {}
    from io import BytesIO
    from PIL import Image
    img = Image.open(src).convert("RGB")
    small = BytesIO()
    img.resize((512, 320), Image.LANCZOS).save(small, "PNG")
    return {"preview.png": small.getvalue(), "fullscreenpreview.jpg": src.read_bytes()}


def build(out, accent="blue", wall="lagoon"):
    if out.exists():
        shutil.rmtree(out)
    wallpaper = f"One-{wall.capitalize()}"
    for mode, scheme, kv in MODES:
        th = resolve(mode, accent, wall)
        write(out, f"share/color-schemes/{scheme}.colors", colors.scheme(th, scheme.replace("One", "One "), scheme))
        svg, cfg = kvantum.build(th, kv)
        write(out, f"config/Kvantum/One/{kv}.svg", svg)
        write(out, f"config/Kvantum/One/{kv}.kvconfig", cfg)
        for rel, data in aurorae.build(th, scheme).items():
            write(out, f"share/aurorae/themes/{scheme}/{rel}", data)
        for rel, data in lnf.build(th, wallpaper).items():
            write(out, f"share/plasma/look-and-feel/{lnf.ident(th.dark)}/{rel}", data)
        for rel, data in previews(mode).items():
            write(out, f"share/plasma/look-and-feel/{lnf.ident(th.dark)}/contents/previews/{rel}", data)
        for rel, data in icons.build(th, icon_theme(th.dark)).items():
            write(out, f"share/icons/{icon_theme(th.dark)}/{rel}", data)
        write(out, f"share/konsole/{scheme}.colorscheme", extras.konsole(th, scheme))
        write(out, f"share/konsole/{scheme}.profile", extras.konsole_profile(scheme).replace("Name=One", f"Name={scheme}"))
    for ver in (3, 4):
        write(out, f"gtk/gtk{ver}.css", extras.gtk_css(resolve("light", accent, wall),
                                                    resolve("dark", accent, wall), ver))
    for rel, data in plasma.build(resolve("light", accent, wall)).items():
        write(out, f"share/plasma/desktoptheme/One/{rel}", data)
    for rel, data in extras.wallpapers().items():
        write(out, f"share/wallpapers/{rel}", data)
    for name, data in extras.fonts().items():
        write(out, f"share/fonts/oneDesign/{name}", data)
    write(out, "etc/plasmalogin.conf.d/one.conf", extras.plasmalogin_conf(wall))
    for rel, data in sddm.build([resolve(m, accent, wall) for m in ("light", "dark")], wall).items():
        write(out, f"share/sddm/themes/one/{rel}", data)
    write(out, "etc/sddm.conf.d/one.conf", "[Theme]\nCurrent=one\nCursorTheme=Adwaita\n")
    qs = HERE / "quicksettings"
    for f in sorted(qs.rglob("*")):
        if f.is_file():
            write(out, f"share/plasma/plasmoids/org.onedesign.quicksettings/{f.relative_to(qs)}", f.read_text())
    write(out, "share/onedesign/lockscreen/LockScreenUi.qml", (HERE / "lockscreen/LockScreenUi.qml").read_text())
    write(out, "config/plasma-workspace/env/onedesign-lockscreen.sh", (HERE / "lockscreen/sync.sh").read_text())
    write(out, "manifest.json", json.dumps({
        "accent": accent, "wallpaper": wallpaper,
        "lookandfeel": {"light": lnf.ident(False), "dark": lnf.ident(True)},
        "fonts": {"/".join(k): v for k, v in extras.font_settings().items()},
    }, indent=2) + "\n")
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--accent", default="blue", help="accent name from tokens, or 'wallpaper'")
    ap.add_argument("--wall", default="lagoon", choices=list(WALLS))
    ap.add_argument("--out", default=str(ROOT / "build" / "kde"))
    a = ap.parse_args()
    out = build(Path(a.out), a.accent, a.wall)
    n = sum(1 for p in out.rglob("*") if p.is_file())
    print(f"built {n} files into {out}")


if __name__ == "__main__":
    main()
