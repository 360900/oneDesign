# One for KDE Plasma

Generated from `tokens/one.json` by `kde/build.py`.
Accent and wallpaper are baked at build time because Kvantum SVGs cannot follow the KDE accent.

## Requirements

- Plasma 6, `kvantum` (Qt widget style), `aurorae` (window decoration engine), `papirus-icon-theme`, `adwaita-icon-theme`
- Python 3 with Pillow and numpy (build only)

`install.sh` installs these and runs the steps below. Run again, it updates and keeps the panels, wallpaper, accent and light/dark choice. `--rollback` returns to the previous version, `--uninstall` removes oneDesign and restores the desktop from before it.

## Use

```sh
kde/one-theme build [--accent blue] [--wall wave] [--shell rail|bar]   # -> build/kde/
kde/one-theme install                                 # -> ~/.local/share, ~/.config
kde/one-theme apply [--mode auto|light|dark] [--layout] [--live] [--keep-wallpaper]
kde/one-theme restore [--original] [--live]           # undo the last apply, or every apply
kde/one-theme uninstall
kde/one-theme dm                                      # prints sudo steps for the login screen
```

`apply` backs up every config it touches into `~/.local/state/onedesign/backup/<time>/`.
`--layout` replaces the panel layout (the left rail, or top bar + dock when built with `--shell bar`); panels are translucent at all times, not only when no window is near. `--live` uses `plasma-apply-*`
on the running session, rebuilds the panels from the layout script and restarts Plasma Shell so changed plasmoids load; without it, configs are written and take effect on next login.

Preview without touching your session (nested KWin, throwaway HOME):

```sh
tools/kde_preview.sh dark /tmp/one.png "dolphin"
```

## What is generated

| Output | Component | Notes |
|---|---|---|
| `share/color-schemes/One{Light,Dark}.colors` | `colors.py` | Merged into kdeglobals on apply |
| `config/Kvantum/One/` | `kvantum.py` | `One` and `OneDark` (style `kvantum` / `kvantum-dark`) |
| `share/plasma/desktoptheme/One{,Dark}/` | `plasma.py` | Glass panels, dialogs, tooltips built from the `glass` tokens per mode (luminosity, tint with accent cast, brightness, outer edge, inner line, specular rim); solid/opaque fallbacks. `apply` sets KWin blur strength from `glass.blur` (blur / 6, so 2 for 12 px) and noise 2 |
| `share/aurorae/themes/One{Light,Dark}/` | `aurorae.py` | Header-colored titlebar, round buttons, soft shadow |
| `share/plasma/look-and-feel/org.onedesign.one{,-dark}.desktop/` | `lnf.py` | Defaults, panel layout, splash, previews |
| `share/wallpapers/One-*/` | `extras.py` | Light and dark images; Plasma switches between them with the color scheme |
| `share/icons/One{,-Dark}/` | `icons.py` | Accent folders, Adwaita symbolic icons, and Papirus art for the text editor, image viewer and file manager; other apps inherit Papirus |
| `share/konsole/` | `extras.py` | Color schemes and profiles |
| `share/fonts/oneDesign/` | `extras.py` | Inter, Geist Mono |
| `freecad/` | `freecad.py` | FreeCAD preference packs `One Light` / `One Dark` (3D view, sketcher, editor, stylesheet over the system Qt style) and a startup hook that swaps them to match the system color scheme, installed into each existing `~/.local/share/FreeCAD/v*` |
| `gtk/gtk{3,4}.css` | `extras.py` | Appended to `gtk-{3,4}.0/gtk.css` between markers (GTK 4: both modes via `prefers-color-scheme`; GTK 3: shape only) |
| `share/plasma/plasmoids/org.onedesign.rail/` | `rail/`, `extras.py` | Rail widget: workspace thumbnails (wallpaper plus miniature windows, click or scroll to switch, hover while dragging to switch, + adds one, right-click removes one) and the pinned and running app column, with its own icon size, spacing and edge marks (one per window). The app column works like KDE's icons-only task manager: same options, clicks, context menu (jump list, recent files, media controls, desktops, activities), window preview tooltips and audio marks. The rail panel is inset with rounded inner corners and grows to full height, flush, with a short animation while a window is maximized on the current desktop (`fillWhenMaximized`, set through the shell's scripting API). The panel's own settings stay in charge: the rail restores the length you set, stands down in edit mode and while the panel floats, and keeps to the left or right edge (a move to the top or bottom is sent back). Desktop switching and creation go through KWin over D-Bus (`qdbus6`) |
| `share/kwin/scripts/onedesign-workspacedrag/` | `workspacedrag/` | KWin script: switches workspace when a moved window hovers a rail thumbnail. KWin holds the pointer during a move, so the rail publishes its thumbnail rectangles in its `workspaceZones` setting and the script reads them through the shell's scripting API |
| `share/plasma/plasmoids/org.onedesign.drawer/` | `drawer/` | Launcher for the rail: opens a full-height glass drawer beside it with search, running apps, pinned apps, all apps by menu category, and a user row with settings, lock and power. Search runs KRunner's own results model, so the Plasma Search settings (enabled plugins, favorites) and categories are the same as in KRunner; right-click a result or an app to pin it to the drawer or the rail. The drawer and the rail keep separate pinned lists. Registers as the launcher menu, so the Meta key opens it |
| `share/plasma/plasmoids/org.onedesign.clock/` | `clock/` | Rail clock: bold hours over minutes with the date under it |
| `share/plasma/plasmoids/org.onedesign.notifications/` | `notifications/` | Round bell for the rail with an unread badge. The stock notifications applet stays loaded in the tray because it draws the toasts; this widget keeps it hidden, so it never shows in the tray or behind its chevron. Click opens the history (clear, dismiss, open the default action) with a Do Not Disturb switch; middle click toggles Do Not Disturb |
| `share/plasma/plasmoids/org.onedesign.quicksettings/` | `quicksettings/` | GNOME-style quick settings menu in the top bar |
| `share/plasma/shells/org.onedesign.desktop/` | `lockscreen/` | Lock screen. The screen locker loads its UI from the Plasma shell package, so this package holds only the lock screen and falls back to KDE's desktop shell for everything else. `apply` makes it the shell (`plasmashellrc` `[Shell] ShellPackage`) and carries the panels and desktop over to its config file; `restore` and `uninstall` switch back |
| `share/sddm/themes/one/`, `etc/sddm.conf.d/one.conf` | `sddm.py`, `sddm/Main.qml` | SDDM greeter |
| `etc/plasmalogin.conf.d/one.conf` | `extras.py` | Plasma Login Manager wallpaper |

## Rail tray

The rail and the drawer have settings (right-click, Configure): layout and order, task filters, grouping, sorting, middle-click and wheel actions, pinned apps. Super opens the drawer.

On the rail the tray's contents sit behind its chevron. `apply --layout` hides the status notifier items that are running at that moment (their ids are read from the session bus). Apps started later show in the rail until you hide them once in the tray's settings.

## Quick settings

`--layout` puts the Quick Settings widget at the right of the top bar: volume and brightness
sliders, Wi-Fi, Bluetooth, power mode, night light, dark style and do not disturb, with
subpages for networks, devices, profiles, sound outputs and power actions. The system tray
next to it is limited to app icons (StatusNotifierItems); notifications get their own widget
beside the clock. Each backend loads separately, so a missing service only hides its controls. On the left rail the status icons stack in a column.

## Login screen

`one-theme dm` prints the steps to switch to SDDM with the One greeter.
Plasma Login Manager compiles its greeter and cannot load a custom theme; `one-theme dm --plm`
prints the steps to at least give it the One wallpaper, colors and Plasma style.
With face or fingerprint login (linux-hello, Howdy, fprintd), press Enter with an empty password
on the SDDM greeter to start it; the module's status shows below the field.

## Limits

- GTK apps get One colors and radii on top of libadwaita / Adwaita-gtk3, not full One widgets.
- FreeCAD picks up light/dark switching on its next start. Select `One Light` or `One Dark` once under Preferences > General > Preference packs.
- Cursor stays Breeze. App and file-type icons come from Papirus; less common Papirus folder variants keep Papirus colors.
