/* Edge refraction for glass surfaces: per-element displacement map fed to an SVG filter used in backdrop-filter. */
(function () {
  let n = 0;
  const NS = "http://www.w3.org/2000/svg";

  function sdRoundRect(x, y, w, h, r) {
    const qx = Math.abs(x - w / 2) - (w / 2 - r);
    const qy = Math.abs(y - h / 2) - (h / 2 - r);
    const ox = Math.max(qx, 0), oy = Math.max(qy, 0);
    return Math.hypot(ox, oy) + Math.min(Math.max(qx, qy), 0) - r;
  }

  function map(w, h, r, bezel) {
    const c = document.createElement("canvas");
    c.width = w; c.height = h;
    const ctx = c.getContext("2d");
    const img = ctx.createImageData(w, h);
    const d = img.data;
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        const i = (y * w + x) * 4;
        const s = -sdRoundRect(x + 0.5, y + 0.5, w, h, r);
        let dx = 0, dy = 0;
        if (s > 0 && s < bezel) {
          const gx = sdRoundRect(x + 1.5, y + 0.5, w, h, r) - sdRoundRect(x - 0.5, y + 0.5, w, h, r);
          const gy = sdRoundRect(x + 0.5, y + 1.5, w, h, r) - sdRoundRect(x + 0.5, y - 0.5, w, h, r);
          const len = Math.hypot(gx, gy) || 1;
          const t = 1 - s / bezel;
          const m = t * t * (3 - 2 * t); // smooth falloff toward the interior
          dx = (gx / len) * m; dy = (gy / len) * m;
        }
        d[i] = 128 + dx * 127; d[i + 1] = 128 + dy * 127; d[i + 2] = 128; d[i + 3] = 255;
      }
    }
    ctx.putImageData(img, 0, 0);
    return c.toDataURL();
  }

  function svgRoot() {
    let s = document.getElementById("lens-defs");
    if (!s) {
      s = document.createElementNS(NS, "svg");
      s.id = "lens-defs";
      s.setAttribute("width", "0"); s.setAttribute("height", "0");
      s.style.position = "absolute";
      document.body.appendChild(s);
    }
    return s;
  }

  function lens(el, strength) {
    const rect = el.getBoundingClientRect();
    const w = Math.round(rect.width), h = Math.round(rect.height);
    if (w < 8 || h < 8) return;
    const rad = Math.min(parseFloat(getComputedStyle(el).borderTopLeftRadius) || 0, h / 2, w / 2);
    const bezel = Math.min(Math.max(rad * 0.9, 10), 28, h / 2);
    const id = "lens" + n++;
    const f = document.createElementNS(NS, "filter");
    f.id = id;
    f.setAttribute("x", "0"); f.setAttribute("y", "0"); f.setAttribute("width", w); f.setAttribute("height", h);
    f.setAttribute("filterUnits", "userSpaceOnUse");
    f.setAttribute("primitiveUnits", "userSpaceOnUse");
    f.setAttribute("color-interpolation-filters", "sRGB");
    f.innerHTML = `<feImage href="${map(w, h, rad, bezel)}" x="0" y="0" width="${w}" height="${h}" result="m" preserveAspectRatio="none"/>
      <feDisplacementMap in="SourceGraphic" in2="m" scale="${strength}" xChannelSelector="R" yChannelSelector="G"/>`;
    svgRoot().appendChild(f);
    el.style.setProperty("--lens-filter", `url(#${id})`);
    el.classList.add("lens");
  }

  window.oneLens = function () {
    if (document.documentElement.dataset.refract !== "1") return;
    const sel = ".mat-glass, .hb-group, .hb-path .pathbar";
    document.querySelectorAll(sel).forEach((el) => {
      const big = el.getBoundingClientRect().width > 500;
      lens(el, big ? 36 : 26);
    });
  };
})();
