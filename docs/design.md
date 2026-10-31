# One

Adwaita structure, Material color, Fluent depth, glass reserved for what floats.
All values live in `tokens/one.json`.

## Principles

- Content is opaque and calm; only floating chrome (shell, popovers, OSDs, toasts) is glass.
- One accent drives everything: tonal neutrals and containers derive from it.
- Concentric geometry: inner radius = outer radius - padding.
- Depth is a hairline stroke plus a soft two-part shadow, never heavy outlines.

Everything inside app windows maps onto libadwaita/GTK and Qt without compositor
tricks, so apps match exactly. Glass lives in the shell and popovers, which we
control fully (shell theme, KWin blur, SDDM).

## Foundation

- **Color.** OKLCH everywhere. One accent hue + chroma (9 presets, or taken from
  the wallpaper) drives accent, accent containers, neutral tint and syntax colors.
  Neutrals are stored as lightness only; chroma is `neutralChroma` at the accent hue.
- **Type.** Inter, Geist Mono. 12/16 caption, 14/20 body, 15/20 heading, 18/24,
  22/28, 28/34 titles, 56/60 display. Titles weight 750, tracking -0.005.
- **Spacing.** 4 px grid. Controls 36, rows 52, horizontal padding 14, headerbar 50.
- **Shape.** Radii window 18, container 14, control 10, small 6. Rounded buttons.
- **Icons.** Adwaita symbolic.
- **Motion.** `cubic-bezier(.2,0,0,1)`, emphasized `cubic-bezier(.05,.7,.1,1)`,
  120/220/380 ms. Spring overshoot on emphasized transitions only.

## Materials

| Surface | Material |
|---|---|
| Window canvas, sidebar, headerbar, dialog | solid |
| Menus, popovers, tooltips | glass |
| Shell (top bar, dock, quick settings, notifications), OSD | glass |

## Glass

Built from layers so it reads the same over any wallpaper:

1. **Luminosity layer.** Neutral white (light) or black (dark) at `glass.lum`. Keeps
   contrast stable regardless of what is behind.
2. **Tint layer.** The float surface color at `glass.tint`, giving the accent cast.
3. **Backdrop.** Blur `glass.blur`, saturate `glass.saturate`, brightness
   `glass.brightness` (lifts light glass, dims dark glass).
4. **Noise.** Grain at `glass.noise` to avoid banding and add material.
5. **Edges.** A crisp 1 px top highlight (`glass.highlight`), a specular rim lit from
   above (`glass.specular`), and an outer hairline (`glass.edge`).
6. **Shadow.** `elevation.float`, a tight contact shadow plus a wide soft one,
   scaled by `elevation.darkFactor` in dark mode.

Controls inside glass use translucent white fills instead of ink fills so the
glass shows through.

## Components

| Component | Style |
|---|---|
| Button | flat tinted; suggested action filled with accent |
| Switch, check | Adwaita switch, rounded check |
| Slider | thin track |
| Tabs, view switcher | pill |
| Lists, preference rows | boxed |
| Selection | accent container |
| Focus | ring |
| Entry | filled |
| Headerbar | solid bar, centered title, close button only |
| Shell | floating top bar + dock, squircle app icons |
