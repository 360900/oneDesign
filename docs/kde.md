# One for KDE Plasma

Generated from `tokens/languages.json` (language `one`) by `kde/build.py`.
Accent and wallpaper are baked at build time because Kvantum SVGs cannot follow the KDE accent.

## Requirements

- Plasma 6, `kvantum` (Qt widget style), `aurorae` (window decoration engine), `papirus-icon-theme`
- Python 3 with Pillow and numpy (build only)

## Use

```sh
kde/one-theme build [--accent blue] [--wall lagoon]   # -> build/kde/
kde/one-theme install                                 # -> ~/.local/share, ~/.config
kde/one-theme apply [--mode auto|light|dark] [--layout] [--live]
kde/one-theme restore                                 # undo the last apply
kde/one-theme uninstall
kde/one-theme dm                                      # prints sudo steps for the login screen
```

`apply` backs up every config it touches into `~/.local/state/onedesign/backup/<time>/`.
`--layout` replaces the panel layout (top bar + dock). `--live` uses `plasma-apply-*`
on the running session; without it, configs are written and take effect on next login.

Preview without touching your session (nested KWin, throwaway HOME):

```sh
tools/kde_preview.sh dark /tmp/one.png "dolphin"
```

## What is generated

| Output | Component | Notes |
|---|---|---|
| `share/color-schemes/One{Light,Dark}.colors` | `colors.py` | Merged into kdeglobals on apply |
| `config/Kvantum/One/` | `kvantum.py` | `One` and `OneDark` (style `kvantum` / `kvantum-dark`) |
| `share/plasma/desktoptheme/One/` | `plasma.py` | Glass panels, dialogs, tooltips (sheen + top-lit rim, no extra saturation); solid/opaque fallbacks. `apply` sets KWin blur strength 15, noise 2 |
| `share/aurorae/themes/One{Light,Dark}/` | `aurorae.py` | Header-colored titlebar, round buttons, soft shadow |
| `share/plasma/look-and-feel/org.onedesign.one{,-dark}.desktop/` | `lnf.py` | Defaults, panel layout, splash, previews |
| `share/wallpapers/One-*/` | `extras.py` | Light and dark images |
| `share/icons/One{,-Dark}/` | `icons.py` | Accent folders, Adwaita symbolic icons; the rest inherits Papirus |
| `share/konsole/` | `extras.py` | Color schemes and profiles |
| `share/fonts/oneDesign/` | `extras.py` | Inter, Geist Mono |
| `gtk/gtk{3,4}.css` | `extras.py` | Appended to `gtk-{3,4}.0/gtk.css` between markers (GTK 4: both modes via `prefers-color-scheme`; GTK 3: shape only) |
| `share/plasma/plasmoids/org.onedesign.quicksettings/` | `quicksettings/` | GNOME-style quick settings menu in the top bar |
| `share/sddm/themes/one/`, `etc/sddm.conf.d/one.conf` | `sddm.py`, `sddm/Main.qml` | SDDM greeter |
| `etc/plasmalogin.conf.d/one.conf` | `extras.py` | Plasma Login Manager wallpaper |

## Quick settings

`--layout` puts the Quick Settings widget at the right of the top bar: volume and brightness
sliders, Wi-Fi, Bluetooth, power mode, night light, dark style and do not disturb, with
subpages for networks, devices, profiles, sound outputs and power actions. The system tray
next to it is limited to app icons (StatusNotifierItems); notifications get their own widget
beside the clock. Each backend loads separately, so a missing service only hides its controls.

## Login screen

`one-theme dm` prints the steps to switch to SDDM with the One greeter.
Plasma Login Manager compiles its greeter and cannot load a custom theme; `one-theme dm --plm`
prints the steps to at least give it the One wallpaper, colors and Plasma style.

## Limits

- GTK apps get One colors and radii on top of libadwaita / Adwaita-gtk3, not full One widgets.
- Lock screen uses the Breeze layout with One style and wallpaper.
- Cursor stays Breeze. App and file-type icons come from Papirus; less common Papirus folder variants keep Papirus colors.
