# oneDesign

A design language for Linux. Calm, opaque content; glass only for what floats; one
accent that tints everything; concentric rounded geometry; depth from hairlines and
soft shadows. Themes KDE Plasma, Qt and GTK apps, window decorations, icons, and the
lock and login screens.

## View

```sh
python3 -m http.server 8000
# open http://localhost:8000/prototypes/
```

The gallery switches scene (desktop, settings, apps, components, login), light/dark,
wallpaper and accent, or shows all scenes side by side. Single scenes:
`prototypes/view.html?scene=desktop&mode=dark&wall=orchid&accent=wallpaper`.

Static renders of every scene and mode are in `renders/`.

## Layout

| Path | What |
|---|---|
| `tokens/one.json` | Source of truth: accents, type, shape, color, materials, glass |
| `docs/design.md` | Design spec |
| `docs/theming-plan.md` | Phase 2: toolkit and DE targets, pipeline, limits |
| `prototypes/assets/engine.js` | Token resolver (OKLCH math, CSS variables) |
| `prototypes/assets/one.css`, `scenes.css` | Component and scene styles |
| `prototypes/assets/scenes.js` | Desktop, settings, apps, components, login scenes |
| `tools/build_icons.py` | Packs Adwaita icons (Fluent, Material fallbacks) into `icons.js` |
| `tools/build_wallpapers.py` | Renders the four wallpapers (light/dark) with Blender |
| `tools/shoot.py` | Headless Chromium renders into `renders/` |
| `docs/kde.md` | One for KDE Plasma: build, install, apply, limits |
| `kde/` | KDE generators (`build.py`) and the `one-theme` CLI |
| `tools/onetokens.py` | Python token resolver, mirrors `engine.js` |
| `tools/kde_preview.sh` | Screenshots the theme in a nested, throwaway Plasma session |
| `tools/qt_gallery.py` | Qt widget gallery for style testing |
| `reference/` | Upstream tokens, icons and fonts used by the generators |

## Credits

Inter (OFL), Geist Mono (OFL), Adwaita icons (CC-BY-SA / LGPL),
Fluent UI System Icons (MIT), Material Symbols (Apache 2.0),
Text editor and image viewer app icons from Papirus (GPL-3.0).

## License

GPL-3.0. Bundled fonts and icons keep their own licenses.
