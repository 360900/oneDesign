/* oneDesign prototype engine: tokens/one.json -> CSS custom properties. */
(function () {
  const WALLS = { dune: 55, lagoon: 220, orchid: 320, moss: 150 };

  const params = new URLSearchParams(location.search);
  const state = {
    mode: params.get("mode") || "light",
    accent: params.get("accent") || "wallpaper",
    wall: params.get("wall") || "lagoon",
    scene: params.get("scene") || document.body.dataset.scene || "desktop",
  };

  const ok = (L, C, H, a) => `oklch(${(+L).toFixed(3)} ${(+C).toFixed(3)} ${(+H).toFixed(1)}${a != null ? " / " + a : ""})`;

  // Shadow alphas are authored for light mode; dark mode multiplies them.
  const scaleShadow = (s, k) => s.replace(/\/\s*([\d.]+)\)/g, (_, a) => `/ ${Math.min(a * k, 0.9).toFixed(3)})`);

  const noise = (alpha) =>
    `url("data:image/svg+xml,${encodeURIComponent(
      `<svg xmlns='http://www.w3.org/2000/svg' width='160' height='160'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='.9' numOctaves='2' stitchTiles='stitch'/><feColorMatrix values='0 0 0 0 .5 0 0 0 0 .5 0 0 0 0 .5 0 0 0 ${alpha} 0'/></filter><rect width='160' height='160' filter='url(#n)'/></svg>`
    )}")`;

  function computeVars(t, mode, hue, chroma) {
    const dark = mode === "dark";
    const n = t.color.neutral[mode];
    const nc = t.color.neutralChroma;
    const v = {};
    for (const role of ["desktop", "canvas", "sidebar", "surface", "surfaceAlt", "float", "headerbar"]) {
      v[`--c-${role.replace(/[A-Z]/g, (m) => "-" + m.toLowerCase())}`] = ok(n[role], nc, hue);
    }
    v["--c-text"] = ok(n.text, nc * 2, hue);
    v["--c-text2"] = ok(n.text2, nc * 2, hue);
    v["--c-text3"] = ok(n.text3, nc * 2, hue);
    const ink = dark ? "255 255 255" : "0 0 0";
    v["--c-stroke"] = `rgb(${ink} / ${n.stroke})`;
    v["--c-stroke-strong"] = `rgb(${ink} / ${n.strokeStrong})`;
    v["--c-hover"] = `rgb(${ink} / ${dark ? 0.07 : 0.05})`;
    v["--c-active"] = `rgb(${ink} / ${dark ? 0.12 : 0.09})`;
    v["--c-fill"] = `rgb(${ink} / ${dark ? 0.09 : 0.06})`;
    v["--c-fill-strong"] = `rgb(${ink} / ${dark ? 0.16 : 0.12})`;
    v["--ink"] = ink;

    const aL = t.color.accent[mode];
    v["--c-accent"] = ok(aL, chroma, hue);
    v["--c-accent-hover"] = ok(aL + (dark ? 0.04 : -0.04), chroma, hue);
    v["--c-on-accent"] = aL > 0.68 ? ok(0.2, Math.min(chroma, 0.06), hue) : "#fff";
    v["--c-accent-text"] = ok(dark ? Math.max(aL, 0.76) : Math.min(aL, 0.52), chroma, hue);
    const [cL, ocL, cf] = t.color.container[mode];
    v["--c-container"] = ok(cL, chroma * cf, hue);
    v["--c-on-container"] = ok(ocL, chroma * 0.8, hue);
    v["--c-accent-soft"] = ok(aL, chroma, hue, dark ? 0.22 : 0.14);

    for (const [k, s] of Object.entries(t.status)) {
      v[`--c-${k}`] = ok(dark ? 0.74 : 0.56, s.chroma, s.hue);
      v[`--c-${k}-soft`] = ok(dark ? 0.74 : 0.56, s.chroma, s.hue, dark ? 0.2 : 0.13);
    }

    const sh = t.shape;
    v["--r-window"] = sh.window + "px";
    v["--r-container"] = sh.container + "px";
    v["--r-control"] = sh.control + "px";
    v["--r-small"] = sh.small + "px";
    v["--r-button"] = sh.control + "px";
    const d = t.density;
    v["--h-control"] = d.control + "px";
    v["--h-row"] = d.row + "px";
    v["--pad-x"] = d.padX + "px";
    v["--gap"] = d.gap + "px";
    v["--h-headerbar"] = d.headerbar + "px";

    const g = t.glass;
    v["--g-blur"] = g.blur + "px";
    v["--g-sat"] = g.saturate;
    v["--g-bright"] = g.brightness[mode];
    v["--g-lum-ink"] = dark ? "0 0 0" : "255 255 255";
    v["--g-lum"] = g.lum[mode];
    v["--g-tint"] = Math.round(g.tint[mode] * 100) + "%";
    v["--g-spec"] = g.specular[mode];
    v["--g-hl"] = g.highlight[mode];
    v["--g-edge"] = g.edge[mode];
    v["--g-line"] = g.line[mode];
    v["--g-accent"] = Math.round(g.accentMix[mode] * 100) + "%";
    v["--g-rim"] = g.rim + "px";
    v["--g-noise"] = noise(g.noise);
    v["--v-fill"] = dark ? 0.1 : 0.5;
    v["--v-fill-strong"] = dark ? 0.18 : 0.72;
    v["--v-hover"] = dark ? 0.07 : 0.35;

    const e = t.elevation;
    const k = dark ? e.darkFactor : 1;
    for (const lvl of ["1", "2", "3", "float"]) v[`--shadow-${lvl}`] = scaleShadow(e[lvl], k);
    v["--stroke-w"] = t.stroke.width + "px";

    const fonts = { Inter: "'InterV', 'Inter'", "Geist Mono": "'GeistMonoV'" };
    v["--font-ui"] = `${fonts[t.font.ui]}, system-ui, sans-serif`;
    v["--font-mono"] = `${fonts[t.font.mono]}, monospace`;
    v["--font-features"] = t.font.features;
    v["--tracking"] = t.type.tracking + "em";
    v["--title-weight"] = t.type.titleWeight;
    for (const [key, ts] of Object.entries(t.typeScale)) {
      v[`--fs-${key}`] = (ts.size * t.type.scale).toFixed(1) + "px";
      v[`--lh-${key}`] = (ts.line * t.type.scale).toFixed(1) + "px";
    }
    const m = t.motion;
    v["--ease"] = m.easing;
    v["--ease-emph"] = m.emphasized;
    v["--t-fast"] = m.fast + "ms";
    v["--t-normal"] = m.normal + "ms";
    v["--t-slow"] = m.slow + "ms";
    return v;
  }

  function apply(tokens) {
    let hue, chroma;
    if (state.accent === "wallpaper") {
      hue = WALLS[state.wall];
      chroma = 0.14;
    } else {
      ({ hue, chroma } = tokens.accents[state.accent]);
    }
    const vars = computeVars(tokens, state.mode, hue, chroma);
    const root = document.documentElement;
    for (const [k, val] of Object.entries(vars)) root.style.setProperty(k, val);
    root.style.setProperty("--wallpaper", `url("${new URL(`assets/wallpapers/${state.wall}-${state.mode}.webp`, location.href).href}")`);
    root.dataset.mode = state.mode;
    root.dataset.scene = state.scene;
    root.style.colorScheme = state.mode;
    window.ONE = { state, tokens, vars, hue, chroma };
  }

  function icon(name, cls = "") {
    return `<span class="ic ${cls}" data-icon="${name}">${window.ONE_ICONS[name] || ""}</span>`;
  }

  function materialize(scope = document) {
    const mats = window.ONE.tokens.materials;
    scope.querySelectorAll("[data-role]").forEach((el) => {
      el.classList.add("mat", "mat-" + (mats[el.dataset.role] || "solid"));
    });
  }

  window.oneIcon = icon;
  window.oneBoot = async function (render) {
    const tokens = await (await fetch("../tokens/one.json")).json();
    apply(tokens);
    document.body.innerHTML = render(window.ONE);
    materialize();
    await document.fonts.ready;
    document.body.dataset.ready = "1";
  };
})();
