# oneDesign

A design language for Linux that mixes Adwaita, Material 3, Fluent 2 and Liquid Glass,
with five proposals rendered as interactive prototypes. Phase 2 generates GTK, Qt,
KDE, GNOME Shell, GDM/SDDM and app themes from the same tokens.

## View

```sh
python3 -m http.server 8000
# open http://localhost:8000/prototypes/
```

The gallery switches language, scene (desktop, settings, apps, components, login),
light/dark, wallpaper and accent, or shows all five side by side. Single scenes:
`prototypes/view.html?lang=one&scene=desktop&mode=dark&wall=orchid&accent=wallpaper`.

Static renders of every language, scene and mode are in `renders/`.

## Layout

| Path | What |
|---|---|
| `tokens/languages.json` | Source of truth: accents, type scale, and the five languages |
| `docs/languages.md` | Language spec and comparison |
| `docs/theming-plan.md` | Phase 2: toolkit and DE targets, pipeline, limits |
| `prototypes/assets/engine.js` | Token resolver (OKLCH math, CSS variables) |
| `prototypes/assets/one.css`, `scenes.css` | Component and scene styles |
| `prototypes/assets/scenes.js` | Desktop, settings, apps, components, login scenes |
| `prototypes/assets/lens.js` | Glass refraction (displacement maps) for Liquid |
| `tools/build_icons.py` | Packs Adwaita, Fluent and Material icons into `icons.js` |
| `tools/build_wallpapers.py` | Generates the four wallpapers (light/dark) |
| `tools/shoot.py` | Headless Chromium renders into `renders/` |
| `docs/kde.md` | One for KDE Plasma: build, install, apply, limits |
| `kde/` | KDE generators (`build.py`) and the `one-theme` CLI |
| `tools/onetokens.py` | Python token resolver, mirrors `engine.js` |
| `tools/kde_preview.sh` | Screenshots the theme in a nested, throwaway Plasma session |
| `tools/qt_gallery.py` | Qt widget gallery for style testing |
| `reference/` | Upstream tokens, icons and fonts the languages are derived from |

## Credits

Inter (OFL), Geist (OFL), Roboto Flex (OFL), Adwaita icons (CC-BY-SA / LGPL),
Fluent UI System Icons (MIT), Material Symbols (Apache 2.0),
Text editor and image viewer app icons from Papirus (GPL-3.0).
