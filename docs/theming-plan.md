# Theming plan (phase 2)

Goal: one command (`one-theme apply --mode <light|dark> --accent <name|wallpaper>`)
that renders every target from `tokens/one.json`. Nothing below is built yet;
this is the plan the prototypes were designed against.

## Targets

| Layer | Target | Mechanism | Notes |
|---|---|---|---|
| Apps | GTK4 / libadwaita | `~/.config/gtk-4.0/gtk.css` overriding named colors (`@define-color accent_bg_color`, `window_bg_color`, ...) plus widget CSS for radii/shapes | libadwaita allows color overrides officially; shape overrides work but are unsupported. No in-window blur. |
| Apps | GTK3 | fork of adw-gtk3 (SCSS) compiled with our tokens | Gives libadwaita look to GTK3 apps. |
| Apps | Qt5/Qt6 | Kvantum theme (SVG + kvconfig) generated from tokens, plus qt5ct/qt6ct palette | Kvantum supports translucency and blur hints on KDE. A native QStyle (fork of Breeze/Darkly) is the long-term option for exact metrics. |
| Apps | KDE apps | `kdeglobals` color scheme + Kvantum or QStyle | Same palette as Qt. |
| Apps | Electron / Chromium | GTK mode + `--gtk-version=4`, color via GTK | Partial: picks up colors and fonts only. |
| Apps | Firefox / Thunderbird | `userChrome.css` + `userContent.css` generated, or a WebExtension theme | Full chrome control. |
| Apps | Flatpak | `flatpak override --filesystem=xdg-config/gtk-4.0:ro` and `GTK_THEME`, Kvantum via `org.kde.KStyle.Kvantum` runtime ext | |
| Apps | Terminals, editors | generated palettes for VTE (GNOME Console/Ptyxis), Konsole, kitty, foot, Alacritty, VS Code, Zed | Syntax colors derive from accent hue (`--syn-*`). |
| DE | GNOME Shell | shell theme (gresource / User Themes) + Blur my Shell config | Glass for panel, dash, popovers, OSD. |
| DE | KDE Plasma | Plasma style (SVG), color scheme, Aurorae or Klassy decoration, KWin blur/contrast, panel layout script | Best compositor support for glass. |
| DE | Hyprland / niri | generated config (gaps, radii, blur, colors) + Waybar/AGS CSS | Optional. |
| DM | GDM | gnome-shell gresource patch for the greeter | Needs root. |
| DM | SDDM | QML theme generated from tokens | Full freedom, glass possible. |
| Base | Icons | Adwaita (`adwaita-icon-theme`) via icon theme inheritance | |
| Base | Fonts | Inter, Geist Mono; fontconfig defaults | |
| Base | Cursors | Adwaita / Bibata | |

## Pipeline

1. `tokens/one.json` is the only source of truth.
2. A Python resolver turns mode + accent into flat values (same math as
   `prototypes/assets/engine.js`; that file is the reference implementation).
3. One small template per target renders files into `build/<mode>/`.
4. `one-theme apply` installs into user dirs; root targets (GDM, SDDM) are a separate,
   explicit step.
5. Screenshot tests: render each target in a container (GTK4 Widget Factory, Qt
   gallery) and diff against the prototype scenes.

## Fidelity limits

- In-window blur or refraction is impossible for third-party GTK/Qt apps; only the
  compositor can blur behind whole surfaces (KWin, Hyprland, Blur my Shell).
