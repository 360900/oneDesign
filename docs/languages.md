# oneDesign languages

Five proposals built from one token schema (`tokens/languages.json`). They share the
same accent palette, type scale and spacing grid, and differ in shape, surface
materials, control styles, motion and shell layout. Pick one (or a mix) and the
generators will be written against that.

Lineage is a rough share of what each language borrows from Adwaita, Material 3,
Fluent 2 and Liquid Glass.

| | One | Calm | Tonal | Layered | Liquid |
|---|---|---|---|---|---|
| Lineage (A/M/F/G) | 35/25/20/20 | 60/10/25/5 | 15/60/10/15 | 15/10/60/15 | 15/10/10/65 |
| UI font | Inter | Inter | Roboto Flex | Geist | Inter |
| Icons | Adwaita symbolic | Adwaita symbolic | Material Symbols | Fluent System | Fluent System |
| Radii window/container/control/small | 18/14/10/6 | 15/12/9/6 | 24/24/20/10 | 8/8/4/3 | 26/22/18/12 |
| Buttons | rounded | rounded | pill | rounded | pill |
| Control / row height | 36 / 52 | 34 / 50 | 40 / 56 | 32 / 46 | 38 / 52 |
| Window canvas | solid | mica tint | tonal | mica | solid |
| Sidebar | solid | solid | tonal | mica | inset glass |
| Menus, popovers | glass | solid | solid | acrylic | glass |
| Shell | glass | solid | tonal glass | acrylic | glass |
| Elevation | soft 2-part | Adwaita | Material | Fluent ramp | glass |
| Shell layout | top bar + floating dock | top bar | floating shelf | taskbar | menu bar + dock |
| Window buttons | close only | close only | min/max/close | min/max/close | traffic dots, left |
| Toolkit fidelity | high | very high | high | medium-high | low (see below) |

## Shared foundation

- **Color.** OKLCH everywhere. One accent hue + chroma (9 presets, or extracted from
  the wallpaper) drives accent, accent containers, neutral tint and syntax colors.
  Neutrals are stored as lightness only; chroma comes from `neutralChroma` x accent hue,
  so every language can run tinted or grey.
- **Type.** 12/16 caption, 14/20 body, 15/20 heading, 18/24, 22/28, 28/34 titles,
  56/60 display. Weight and tracking for titles are per language.
- **Spacing.** 4 px grid. Density tokens set control height, row height, horizontal
  padding and headerbar height.
- **Shape.** Four radii per language. Concentric languages compute inner radii as
  outer minus padding.
- **Motion.** Per-language easing, emphasized easing and three durations. Spring
  languages overshoot on emphasized transitions only.

## One (recommended)

The synthesis. Adwaita structure and widgets, Material color derivation, Fluent
depth, glass only on things that float.

- Content is opaque and calm; only floating chrome (shell, popovers, OSDs, toasts) is glass.
- One accent drives everything: tonal neutrals and containers derive from it.
- Concentric geometry: inner radius = outer radius - padding.
- Depth is a hairline stroke plus a soft two-part shadow, never heavy outlines.

Why recommended: everything inside app windows maps onto libadwaita/GTK and Qt
without compositor tricks, so apps match exactly. The glass lives in the shell
and popovers, which we control fully (shell theme, KWin/compositor blur, SDDM).

## Calm

Adwaita-first. Flat, quiet, legible. A faint wallpaper tint on the window canvas
(Mica-like) instead of blur; nothing translucent inside apps.

- Every surface is opaque, so GTK3, Qt and Electron can match it exactly.
- Few borders, generous whitespace, strong typographic hierarchy.
- Accent used sparingly: suggested actions, selection, focus.

Safest option. Closest to stock GNOME, the least distinctive.

## Tonal

Material-first. Wallpaper-driven dynamic color, tonal surface containers,
expressive pill shapes, no strokes.

- Hierarchy by tone, not lines: containers step lighter or darker in the accent hue.
- Full pills for actions, large radii, shape morphs on press.
- The whole system re-tints when the wallpaper changes.
- Emphasized motion with spring overshoot.

Very feasible with GTK/Qt color overrides. Pills and large radii fight with
some legacy Qt/GTK3 widgets (dense tables, toolbars).

## Layered

Fluent-first. Mica canvas, Acrylic flyouts, hairline strokes, elevation ramps and
compact precision.

- Mica base, solid layer cards, Acrylic transient surfaces.
- Every elevated surface has a 1 px stroke, lighter on top.
- Compact controls with small radii; accent pill indicators for selection.
- Fast, functional motion, no overshoot.

Good fit for KDE (Kvantum, KWin blur, taskbar layout). Real Mica needs the
compositor to sample the wallpaper behind windows; we fake it with a static tint.

## Liquid

Glass-first. Refractive capsules float over edge-to-edge content.

- Toolbars, sidebars and tab bars float above content as glass capsules.
- Specular rim, inner glow and edge refraction sell the thickness.
- Controls nest concentrically inside their containers.
- Glass darkens over light content and lightens over dark content.

The most striking and the least portable. Toolkits cannot blur or refract
what is behind a widget inside their own window; the floating-capsule layout
needs app cooperation. Realistic only in the shell, SDDM and our own apps.
Inside third-party apps it degrades to "One" with pill shapes.

## Component rules (all languages)

| Component | Token keys |
|---|---|
| Button | `controls.button`, `controls.suggested`, `shape.button`, `shape.control` |
| Switch, check, radio | `controls.switch`, `controls.check` |
| Slider, progress | `controls.slider` |
| Tabs, view switcher | `controls.tabs` |
| Lists, preference rows | `controls.list`, `density.row`, `shape.container` |
| Selection in sidebars/lists | `controls.selection` |
| Focus | `controls.focus` |
| Entry | `controls.entry` |
| Headerbar | `controls.toolbar`, `controls.title`, `controls.wm`, `materials.headerbar` |
| Popover, menu, tooltip | `materials.float`, `shape.container` |
| Dialog | `materials.dialog`, `shape.window` |
| Shell (panel, dock, quick settings, notifications) | `shell.*`, `materials.shell` |
