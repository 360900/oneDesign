#!/usr/bin/env python3
"""Bundle reference SVG icons into prototypes/assets/icons.js, keyed by semantic name."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REF = ROOT / "reference" / "icons"
OUT = ROOT / "prototypes" / "assets" / "icons.js"

# semantic name -> (adwaita, fluent, material)
MAP = {
    "folder": ("folder-symbolic", "folder", "folder"),
    "home": ("user-home-symbolic", "home", "home"),
    "search": ("edit-find-symbolic", "search", "search"),
    "add": ("list-add-symbolic", "add", "add"),
    "back": ("go-previous-symbolic", "arrow-left", "arrow_back"),
    "forward": ("go-next-symbolic", "arrow-right", "arrow_forward"),
    "menu": ("open-menu-symbolic", "menu", "menu"),
    "more": ("view-more-symbolic", "more", "more_horiz"),
    "save": ("document-save-symbolic", "save", "save"),
    "copy": ("edit-copy-symbolic", "copy", "content_copy"),
    "refresh": ("view-refresh-symbolic", "refresh", "refresh"),
    "wifi": ("network-wireless-signal-excellent-symbolic", None, "wifi"),
    "volume": ("audio-volume-high-symbolic", "volume", "volume_up"),
    "night": ("night-light-symbolic", "night", "dark_mode"),
    "sun": ("weather-clear-symbolic", "sunny", "light_mode"),
    "bluetooth": ("bluetooth-active-symbolic", "bluetooth", "bluetooth"),
    "settings": ("emblem-system-symbolic", "settings", "settings"),
    "trash": ("user-trash-symbolic", "trash", "delete"),
    "documents": ("folder-documents-symbolic", "document", "description"),
    "download": ("folder-download-symbolic", "download", "download"),
    "pictures": ("folder-pictures-symbolic", "image", "image"),
    "power": ("system-shutdown-symbolic", "power", "power_settings_new"),
    "brightness": ("display-brightness-symbolic", "brightness", "brightness_6"),
    "grid": ("view-grid-symbolic", "grid", "grid_view"),
    "list": ("view-list-symbolic", "list", "view_list"),
    "file": ("text-x-generic-symbolic", "document", "description"),
    "image": ("image-x-generic-symbolic", "image", "image"),
    "person": ("avatar-default-symbolic", "person", "person"),
    "send": ("mail-send-symbolic", "send", "send"),
    "mail": ("mail-unread-symbolic", "mail", "mail"),
    "battery": ("battery-level-80-symbolic", "battery", "battery_5_bar"),
    "check": ("object-select-symbolic", "check", "check"),
    "chevron-down": ("pan-down-symbolic", "chevron-down", "expand_more"),
    "chevron-right": ("pan-end-symbolic", "chevron-right", "keyboard_arrow_right"),
    "close": ("window-close-symbolic", "close", "close"),
    "minimize": ("window-minimize-symbolic", "minimize", "remove"),
    "maximize": ("window-maximize-symbolic", "maximize", "crop_square"),
    "palette": ("preferences-desktop-appearance-symbolic", "palette", "palette"),
    "bell": ("preferences-system-notifications-symbolic", "bell", "notifications"),
    "lock": ("system-lock-screen-symbolic", "lock", "lock"),
    "tune": ("preferences-system-symbolic", "tune", "tune"),
    "computer": ("computer-symbolic", "computer", "computer"),
}


def clean(svg: str) -> str:
    svg = re.sub(r"<\?xml.*?\?>", "", svg)
    svg = re.sub(r'\s(width|height)="[^"]*"', "", svg, count=2)
    svg = re.sub(r'fill="(?!none)[^"]*"', 'fill="currentColor"', svg)
    svg = re.sub(r"\s+", " ", svg).strip()
    if "fill=" not in svg.split(">", 1)[0]:
        svg = svg.replace("<svg ", '<svg fill="currentColor" ', 1)
    return svg


def load(family: str, name: str | None) -> str | None:
    if not name:
        return None
    p = REF / family / f"{name}.svg"
    return clean(p.read_text()) if p.exists() else None


def main() -> None:
    # Adwaita symbolic first; Fluent then Material fill gaps Adwaita doesn't cover.
    out = {}
    for key, (adw, flu, mat) in MAP.items():
        out[key] = load("adwaita", adw) or load("fluent", flu) or load("material", mat)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("window.ONE_ICONS = " + json.dumps(out, separators=(",", ":")) + ";\n")
    missing = [k for k, v in out.items() if not v]
    print(f"wrote {OUT} ({OUT.stat().st_size // 1024} KB), missing: {missing}")


if __name__ == "__main__":
    main()
