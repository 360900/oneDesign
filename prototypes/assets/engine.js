/* oneDesign prototype engine: tokens/languages.json -> CSS custom properties + data attributes. */
(function () {
  const ICON_FAMILY = { adwaita: "adwaita", fluent: "fluent", material: "material" };
  const WALLS = { dune: 55, lagoon: 220, orchid: 320, moss: 150 };

  const params = new URLSearchParams(location.search);
  const state = {
    lang: params.get("lang") || "one",
    mode: params.get("mode") || "light",
    accent: params.get("accent") || "wallpaper",
    wall: params.get("wall") || "lagoon",
    scene: params.get("scene") || document.body.dataset.scene || "desktop",
  };

  const ok = (L, C, H, a) => `oklch(${(+L).toFixed(3)} ${(+C).toFixed(3)} ${(+H).toFixed(1)}${a != null ? " / " + a : ""})`;

  function shadows(style, dark) {
    const k = dark ? 1.8 : 1;
    const a = (x) => (Math.min(x * k, 0.9)).toFixed(3);
    switch (style) {
      case "adwaita":
        return [
          `0 0 0 1px rgb(0 0 0 / ${a(0.03)}), 0 1px 3px rgb(0 0 0 / ${a(0.07)})`,
          `0 1px 5px 1px rgb(0 0 0 / ${a(0.09)}), 0 2px 14px 3px rgb(0 0 0 / ${a(0.05)})`,
          `0 1px 3px 1px rgb(0 0 0 / ${a(0.09)}), 0 2px 14px 5px rgb(0 0 0 / ${a(0.09)})`,
        ];
      case "material":
        return [
          "none",
          `0 1px 3px rgb(0 0 0 / ${a(0.12)}), 0 4px 10px 3px rgb(0 0 0 / ${a(0.08)})`,
          `0 4px 4px rgb(0 0 0 / ${a(0.10)}), 0 8px 24px 6px rgb(0 0 0 / ${a(0.12)})`,
        ];
      case "fluent":
        return [
          `0 0 2px rgb(0 0 0 / ${a(0.06)}), 0 1px 2px rgb(0 0 0 / ${a(0.07)})`,
          `0 0 2px rgb(0 0 0 / ${a(0.12)}), 0 8px 16px rgb(0 0 0 / ${a(0.14)})`,
          `0 0 8px rgb(0 0 0 / ${a(0.12)}), 0 32px 64px rgb(0 0 0 / ${a(0.24)})`,
        ];
      case "glass":
        return [
          `0 1px 2px rgb(0 0 0 / ${a(0.05)})`,
          `0 10px 36px -6px rgb(0 0 0 / ${a(0.22)}), 0 2px 6px rgb(0 0 0 / ${a(0.06)})`,
          `0 30px 80px -20px rgb(0 0 0 / ${a(0.38)}), 0 4px 14px rgb(0 0 0 / ${a(0.08)})`,
        ];
      default: // soft
        return [
          `0 1px 2px rgb(0 0 0 / ${a(0.05)})`,
          `0 1px 2px rgb(0 0 0 / ${a(0.06)}), 0 10px 28px -6px rgb(0 0 0 / ${a(0.18)})`,
          `0 2px 6px rgb(0 0 0 / ${a(0.07)}), 0 28px 70px -18px rgb(0 0 0 / ${a(0.36)})`,
        ];
    }
  }

  function computeVars(t, lang, mode, hue, chroma) {
    const dark = mode === "dark";
    const n = lang.color.neutral[mode];
    const nc = lang.color.neutralChroma;
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

    const aL = lang.color.accent[mode];
    v["--c-accent"] = ok(aL, chroma, hue);
    v["--c-accent-hover"] = ok(aL + (dark ? 0.04 : -0.04), chroma, hue);
    v["--c-on-accent"] = aL > 0.68 ? ok(0.2, Math.min(chroma, 0.06), hue) : "#fff";
    v["--c-accent-text"] = ok(dark ? Math.max(aL, 0.76) : Math.min(aL, 0.52), chroma, hue);
    const [cL, ocL, cf] = lang.color.container[mode];
    v["--c-container"] = ok(cL, chroma * cf, hue);
    v["--c-on-container"] = ok(ocL, chroma * 0.8, hue);
    v["--c-accent-soft"] = ok(aL, chroma, hue, dark ? 0.22 : 0.14);
    v["--c-wall-tint"] = ok(dark ? 0.32 : 0.86, chroma * 0.7, hue);

    for (const [k, s] of Object.entries(t.status)) {
      v[`--c-${k}`] = ok(dark ? 0.74 : 0.56, s.chroma, s.hue);
      v[`--c-${k}-soft`] = ok(dark ? 0.74 : 0.56, s.chroma, s.hue, dark ? 0.2 : 0.13);
    }

    const sh = lang.shape;
    v["--r-window"] = sh.window + "px";
    v["--r-container"] = sh.container + "px";
    v["--r-control"] = sh.control + "px";
    v["--r-small"] = sh.small + "px";
    v["--r-button"] = sh.button === "pill" ? "999px" : sh.control + "px";
    const d = lang.density;
    v["--h-control"] = d.control + "px";
    v["--h-row"] = d.row + "px";
    v["--pad-x"] = d.padX + "px";
    v["--gap"] = d.gap + "px";
    v["--h-headerbar"] = d.headerbar + "px";

    const g = lang.glass;
    v["--g-blur"] = g.blur + "px";
    v["--g-sat"] = g.saturate;
    v["--g-tint"] = Math.round(g.tint[mode] * 100) + "%";
    v["--g-spec"] = g.specular;
    v["--g-rim"] = g.rim + "px";

    const [s1, s2, s3] = shadows(lang.elevation, dark);
    v["--shadow-1"] = s1;
    v["--shadow-2"] = s2;
    v["--shadow-3"] = s3;
    v["--stroke-w"] = lang.stroke.width + "px";

    const fonts = { Inter: "'InterV', 'Inter'", Geist: "'GeistV'", "Roboto Flex": "'RobotoFlexV'", "Geist Mono": "'GeistMonoV'" };
    v["--font-ui"] = `${fonts[lang.font.ui]}, system-ui, sans-serif`;
    v["--font-mono"] = `${fonts[lang.font.mono]}, monospace`;
    v["--font-features"] = lang.font.features;
    v["--tracking"] = lang.type.tracking + "em";
    v["--title-weight"] = lang.type.titleWeight;
    for (const [k, ts] of Object.entries(t.base.typeScale)) {
      v[`--fs-${k}`] = (ts.size * lang.type.scale).toFixed(1) + "px";
      v[`--lh-${k}`] = (ts.line * lang.type.scale).toFixed(1) + "px";
    }
    const m = lang.motion;
    v["--ease"] = m.easing;
    v["--ease-emph"] = m.emphasized;
    v["--t-fast"] = m.fast + "ms";
    v["--t-normal"] = m.normal + "ms";
    v["--t-slow"] = m.slow + "ms";
    return v;
  }

  function apply(tokens) {
    const lang = tokens.languages.find((l) => l.id === state.lang) || tokens.languages[0];
    let hue, chroma;
    if (state.accent === "wallpaper") {
      hue = WALLS[state.wall];
      chroma = 0.14;
    } else {
      ({ hue, chroma } = tokens.accents[state.accent]);
    }
    const vars = computeVars(tokens, lang, state.mode, hue, chroma);
    const root = document.documentElement;
    for (const [k, val] of Object.entries(vars)) root.style.setProperty(k, val);
    root.style.setProperty("--wallpaper", `url("${new URL(`assets/wallpapers/${state.wall}-${state.mode}.webp`, location.href).href}")`);
    root.dataset.lang = lang.id;
    root.dataset.mode = state.mode;
    root.dataset.elevation = lang.elevation;
    root.dataset.refract = lang.glass.refract ? "1" : "0";
    root.dataset.noise = lang.glass.noise ? "1" : "0";
    root.dataset.concentric = lang.shape.concentric ? "1" : "0";
    for (const [k, val] of Object.entries(lang.controls)) root.dataset[k] = val;
    for (const [k, val] of Object.entries(lang.materials)) root.dataset["mat" + k[0].toUpperCase() + k.slice(1)] = val;
    root.dataset.shell = lang.shell.layout;
    root.dataset.shellFloating = lang.shell.floating ? "1" : "0";
    root.dataset.appIcon = lang.shell.appIcon;
    root.dataset.scene = state.scene;
    root.style.colorScheme = state.mode;
    window.ONE = { state, lang, tokens, vars, hue, chroma };
    return lang;
  }

  function icon(name, cls = "") {
    const lang = window.ONE.lang;
    const fam = ICON_FAMILY[lang.icons] || "adwaita";
    const svg = (window.ONE_ICONS[fam] || {})[name] || window.ONE_ICONS.fluent[name] || "";
    return `<span class="ic ${cls}" data-icon="${name}">${svg}</span>`;
  }

  function materialize(scope = document) {
    const mats = window.ONE.lang.materials;
    scope.querySelectorAll("[data-role]").forEach((el) => {
      const role = el.dataset.role;
      const mat = mats[role] || "solid";
      el.classList.add("mat", "mat-" + mat);
    });
  }

  window.oneIcon = icon;
  window.oneBoot = async function (render) {
    const tokens = await (await fetch("../tokens/languages.json")).json();
    apply(tokens);
    document.body.innerHTML = render(window.ONE);
    materialize();
    await document.fonts.ready;
    document.body.dataset.ready = "1";
  };
})();
