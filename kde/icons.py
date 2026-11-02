"""One icon theme: accent folders + Adwaita symbolic UI icons, everything else inherited from Papirus."""
import re
from pathlib import Path

from onetokens import Color

ADWAITA = Path("/usr/share/icons/Adwaita/symbolic")
APP_ART = Path(__file__).resolve().parent.parent / "reference/icons/apps"
NEUTRAL = re.compile(r"#(2e3436|2e3434|474747|222|222222|2d3336)\b", re.I)

# folder icon name -> Adwaita symbolic glyph (None = plain folder)
FOLDERS = {
    "folder": None, "inode-directory": None, "folder-temp": None,
    "folder-documents": "x-office-document",
    "folder-download": "document-save", "folder-downloads": "document-save",
    "folder-music": "audio-x-generic", "folder-sound": "audio-x-generic", "library-music": "audio-x-generic",
    "folder-pictures": "image-x-generic", "folder-images": "image-x-generic", "folder-image": "image-x-generic",
    "folder-photos": "image-x-generic", "folder-picture": "image-x-generic",
    "folder-videos": "video-x-generic", "folder-video": "video-x-generic",
    "folder-desktop": "computer", "user-desktop": "computer", "desktop": "computer",
    "folder-templates": "document-new",
    "folder-publicshare": "preferences-system-sharing", "folder-public": "preferences-system-sharing",
    "user-home": "user-home", "folder-home": "user-home",
    "folder-remote": "network-server", "folder-network": "network-server",
    "folder-recent": "document-open-recent",
    "folder-favorites": "starred", "folder-bookmark": "starred", "folder-bookmarks": "starred",
    "user-bookmarks": "starred",
    "folder-games": "applications-games",
    "folder-locked": "system-lock-screen", "folder-encrypted": "system-lock-screen",
    "folder-private": "system-lock-screen",
    "folder-development": "utilities-terminal", "folder-code": "utilities-terminal",
    "folder-projects": "utilities-terminal", "folder-script": "utilities-terminal",
    "folder-cloud": "weather-overcast", "folder-important": "emblem-important",
    "folder-root": "drive-harddisk", "folder-cd": "media-optical", "folder-camera": "camera-photo",
    "folder-applications": "application-x-executable",
}
# KDE power applet names -> Adwaita glyphs, so battery-less PCs don't show batteries
ALIASES = {
    "klipper": "edit-paste",
    "speedometer": "power-profile-balanced",
    "battery-profile-performance": "power-profile-performance",
    "battery-profile-powersave": "power-profile-power-saver",
    "edit-clear-history": "edit-clear-all",
    "network-wired-activated": "network-wired",
    "network-wired-disconnected": "network-wired-disconnected",
    "network-wireless-disconnected": "network-wireless-offline",
    "network-unavailable": "network-offline",
    "network-flightmode-on": "airplane-mode",
}
_SIGNAL = {0: "none", 20: "weak", 40: "ok", 60: "good", 80: "excellent", 100: "excellent"}
for _s, _n in _SIGNAL.items():
    for _sfx in ("", "-locked"):
        ALIASES[f"network-wireless-{_s}{_sfx}"] = f"network-wireless-signal-{_n}"
    ALIASES[f"network-wireless-connected-{_s:02d}" if _s == 0 else f"network-wireless-connected-{_s}"] = f"network-wireless-signal-{_n}"
# Tray items render at 22px while the quick settings glyphs are 16px; a padded
# canvas keeps these at the same visual size.
PADDED = {"klipper"}
NEUTRAL_DEFAULT = ("edit-undo", "edit-redo", "edit-select")
OPEN = ("folder", "folder-documents", "folder-download", "folder-music", "folder-pictures",
        "folder-videos", "folder-templates", "folder-publicshare", "folder-remote", "user-home")


def _pad(svg, p):
    """Grow a 16px symbolic canvas by p on every side, glyph unchanged."""
    n = 16 + 2 * p
    head = re.search(r"<svg[^>]*>", svg).group(0)
    new = re.sub(r'\s(width|height|viewBox)="[^"]*"', "", head)
    new = new.replace("<svg", f'<svg width="{n}" height="{n}" viewBox="{-p} {-p} {n} {n}"', 1)
    return svg.replace(head, new, 1)


def _inner(path):
    text = path.read_text()
    m = re.search(r"<svg[^>]*>(.*)</svg>", text, re.S)
    return m.group(1) if m else ""


def _recolor(body):
    """Neutral fills become currentColor with the KDE color-scheme class; status colors stay."""
    def tag(m):
        t = m.group(0)
        if NEUTRAL.search(t):
            t = NEUTRAL.sub("currentColor", t)
        elif re.search(r"\bfill=|fill:|class=", t):
            return t
        else:
            t = re.sub(r"^<(\w+)", r'<\1 fill="currentColor"', t)
        if "class=" not in t:
            t = re.sub(r"^<(\w+)", r'<\1 class="ColorScheme-Text"', t)
        return t
    return re.sub(r"<(path|rect|circle|ellipse|polygon|g)\b[^>]*?/?>", tag, body)


def symbolic(path, default):
    body = _recolor(_inner(path))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">'
            f'<style id="current-color-scheme" type="text/css">.ColorScheme-Text {{ color:{default}; }}</style>'
            f'{body}</svg>\n')


def _glyph(name, x, y, size, color):
    files = list(ADWAITA.glob(f"*/{name}-symbolic.svg"))
    if not files:
        return ""
    body = NEUTRAL.sub("currentColor", _inner(files[0]))
    s = size / 16
    return f'<g transform="translate({x - size / 2:g} {y - size / 2:g}) scale({s:g})" fill="currentColor" color="{color}">{body}</g>'


def folder(th, glyph, open_=False, small=False):
    h, c = th.hue, max(.03, min(th.chroma * .85, .13))
    back = Color.oklch(.6, c, h).hexs
    top = Color.oklch(.77, c * .92, h).hexs
    bot = Color.oklch(.66, c, h).hexs
    gid = "g" + ("s" if small else "l") + ("o" if open_ else "")
    if small:
        dy = 1.5 if open_ else 0
        body = (f'<path d="M1 3.5a1.5 1.5 0 0 1 1.5-1.5h3l1.5 1.5h6.5a1.5 1.5 0 0 1 1.5 1.5v7.5H1z" fill="{back}"/>'
                + ('<rect x="2.5" y="4.5" width="11" height="6" rx=".8" fill="#fff" opacity=".92"/>' if open_ else "")
                + f'<rect x="1" y="{5 + dy}" width="14" height="{9 - dy}" rx="1.5" fill="url(#{gid})"/>'
                f'<rect x="1.5" y="{5.5 + dy}" width="13" height=".6" rx=".3" fill="#fff" opacity=".35"/>')
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">'
                f'<defs><linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
                f'<stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bot}"/></linearGradient></defs>'
                f'{body}</svg>\n')
    dy = 5 if open_ else 0
    body = (f'<rect x="4" y="54" width="56" height="3" rx="1.5" fill="#000" opacity=".12"/>'
            f'<path d="M4 15a5 5 0 0 1 5-5h13.5l5 5H55a5 5 0 0 1 5 5v32H4z" fill="{back}"/>'
            + ('<rect x="8" y="17" width="48" height="26" rx="2.5" fill="#fff" opacity=".95"/>'
               '<rect x="8" y="17" width="48" height="26" rx="2.5" fill="none" stroke="#000" stroke-opacity=".06"/>'
               if open_ else "")
            + f'<rect x="4" y="{21 + dy}" width="56" height="{35 - dy}" rx="6" fill="url(#{gid})"/>'
            f'<rect x="7" y="{22 + dy}" width="50" height="1" rx=".5" fill="#fff" opacity=".4"/>'
            + (_glyph(glyph, 32, 39 + dy / 2, 22, "#fff").replace('<g ', '<g opacity=".9" ', 1) if glyph else ""))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'
            f'<defs><linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bot}"/></linearGradient></defs>'
            f'{body}</svg>\n')


def app_art(name):
    return (APP_ART / f"{name}.svg").read_text()


APPS = {
    "editor": ("kate", "org.kde.kate", "kwrite", "org.kde.kwrite", "accessories-text-editor", "text-editor"),
    "viewer": ("gwenview", "org.kde.gwenview", "image-viewer", "eog"),
    "files": ("org.kde.dolphin", "dolphin", "system-file-manager", "file-manager"),
}


DIRS = {
    "apps/64": ("Applications", 64, 16, 512),
    "places/16": ("Places", 16, 16, 24),
    "places/64": ("Places", 64, 25, 512),
    "actions/16": ("Actions", 16, 16, 512),
}


def index(name, dark, ctxs):
    dirs = dict(DIRS)
    for ctx in ctxs:
        dirs[f"symbolic/{ctx}"] = (ctx.capitalize(), 16, 16, 512)
    out = [
        "[Icon Theme]", f"Name={name}",
        "Comment=oneDesign: accent folders and Adwaita symbolic icons on top of Papirus",
        f"Inherits={'Papirus-Dark,breeze-dark' if dark else 'Papirus,breeze'},hicolor",
        "Example=folder", "FollowsColorScheme=true",
        "DesktopDefault=48", "ToolbarDefault=22", "MainToolbarDefault=22", "SmallDefault=16",
        "PanelDefault=48", "DialogDefault=48",
        "Directories=" + ",".join(dirs), "",
    ]
    for d, (ctx, size, lo, hi) in dirs.items():
        out += [f"[{d}]", f"Context={ctx}", f"Size={size}", f"MinSize={lo}", f"MaxSize={hi}", "Type=Scalable", ""]
    return "\n".join(out)


def build(th, name):
    default = th.c["text"].hexs
    files = {}
    for icon, glyph in FOLDERS.items():
        files[f"places/64/{icon}.svg"] = folder(th, glyph)
        files[f"places/16/{icon}.svg"] = folder(th, glyph, small=True)
    for icon in OPEN:
        files[f"places/64/{icon}-open.svg"] = folder(th, FOLDERS[icon], open_=True)
        files[f"places/16/{icon}-open.svg"] = folder(th, FOLDERS[icon], open_=True, small=True)
    files["places/64/folder-drag-accept.svg"] = files["places/64/folder-open.svg"]
    files["places/16/folder-drag-accept.svg"] = files["places/16/folder-open.svg"]
    art = {"editor": app_art("papirus-text-editor"), "viewer": app_art("papirus-image-viewer"),
           "files": files["places/64/folder.svg"]}
    for key, names in APPS.items():
        for n in names:
            files[f"apps/64/{n}.svg"] = art[key]
    ctxs = []
    for ctxdir in sorted(p for p in ADWAITA.iterdir() if p.is_dir()):
        if ctxdir.name == "legacy":
            continue
        ctxs.append(ctxdir.name)
        for f in sorted(ctxdir.glob("*-symbolic*.svg")):
            files[f"symbolic/{ctxdir.name}/{f.name}"] = symbolic(f, default)
            plain = f.name.replace("-symbolic", "")
            if ctxdir.name == "actions" and "rtl" not in f.name:
                files[f"actions/16/{plain}"] = files[f"symbolic/{ctxdir.name}/{f.name}"]
    # Spectacle draws these on a dark pill and does not recolor them, so the default must read on dark too
    for n in NEUTRAL_DEFAULT:
        src = next(ADWAITA.glob(f"actions/{n}-symbolic.svg"), None)
        if src:
            files[f"actions/16/{n}.svg"] = symbolic(src, "#aeb4bd")
    for kde_name, adw in ALIASES.items():
        src = next(ADWAITA.glob(f"*/{adw}-symbolic.svg"))
        svg = symbolic(src, default)
        if kde_name in PADDED:
            svg = _pad(svg, 3)
        files[f"symbolic/status/{kde_name}-symbolic.svg"] = svg
        files[f"actions/16/{kde_name}.svg"] = files[f"symbolic/status/{kde_name}-symbolic.svg"]
    files["index.theme"] = index(name, th.dark, ctxs)
    return files
