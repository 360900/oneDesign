/* oneDesign prototype scenes. Each scene returns markup built from the component layer in one.css. */
(function () {
  const I = (n, c) => window.oneIcon(n, c);
  const tok = () => window.ONE.tokens;

  const wm = () => `<div class="wm"><span class="wb close">${I("close")}</span></div>`;

  function hb(groups, opts = {}) {
    const g = groups.map((x) => (x.startsWith("<!--raw-->") ? x : `<div class="hb-group">${x}</div>`)).join("");
    return `<header class="headerbar ${opts.sep ? "sep" : ""}" data-role="headerbar">${g}</header>`;
  }
  const raw = (x) => "<!--raw-->" + x;
  const title = (t, sub) => raw(`<div class="title">${t}${sub ? `<small>${sub}</small>` : ""}</div>`);
  const spacer = raw(`<div class="spacer"></div>`);

  function sideItem(icon, label, active, badge) {
    return `<div class="side-item ${active ? "active" : ""}">${I(icon)}<span>${label}</span>${badge ? `<span class="badge soft">${badge}</span>` : ""}</div>`;
  }

  function sidebar(items, headExtra = "", w = 230) {
    const head = `<div class="side-head"><div class="spacer"></div>${headExtra}</div>`;
    return `<aside class="sidebar" data-role="sidebar" style="--sidebar-w:${w}px">${head}${items}</aside>`;
  }

  /* ---------------- Files window ---------------- */
  function filesWindow(style, backdrop) {
    const items = [
      sideItem("home", "Home", true),
      sideItem("computer", "Desktop"),
      sideItem("documents", "Documents"),
      sideItem("download", "Downloads", false, "3"),
      sideItem("pictures", "Pictures"),
      sideItem("trash", "Trash"),
      `<div class="side-label">Devices</div>`,
      sideItem("computer", "Filesystem"),
      sideItem("folder", "Projects"),
    ].join("");
    const nav = `<span class="btn icon flat">${I("back")}</span><span class="btn icon flat dim">${I("forward")}</span>`;
    const path = `<div class="pathbar grow"><span class="crumb">${I("home")}</span>${I("chevron-right", "sep")}<span class="crumb cur">Projects</span></div>`;
    const tools = `<span class="btn icon flat">${I("search")}</span><span class="btn icon flat">${I("grid")}</span><span class="btn icon flat">${I("menu")}</span>`;
    const groups = [nav, raw(`<div class="hb-path grow">${path}</div>`), tools, raw(wm())];
    const files = [
      ["folder", "Design", 245], ["folder", "Firmware", 150], ["folder", "Photos", 30], ["folder", "Website", 300],
      ["folder", "Archive", 250], ["doc", "notes.md"], ["doc", "budget.ods"], ["img", "cover.png"],
      ["doc", "README"], ["img", "render-02.png"], ["folder", "Music", 350], ["doc", "invoice.pdf"],
    ].map(([k, n, h], i) => {
      const inner = k === "folder" ? I(["documents", "settings", "pictures", "palette", "folder", "", "", "", "", "", "volume"][i] || "folder") : k === "doc" ? `<div class="lines"><i></i><i></i><i></i></div>` : "";
      return `<div class="fitem ${i === 5 ? "sel" : ""}"><div class="ficon ${k}" style="--fh:${h || 245}">${inner}</div><span class="fname">${n}</span></div>`;
    }).join("");
    return `<div class="window ${backdrop ? "backdrop" : ""}" data-role="canvas" style="${style}">
      <div class="win-row">
        ${sidebar(items, `<span class="btn icon flat">${I("search")}</span>`)}
        <div class="pane" data-role="canvas">
          ${hb(groups, { sep: true })}
          <div class="under-hb grow scroll">
            <div class="files-grid">${files}</div>
          </div>
          <div class="statusbar"><span>“notes.md” selected (2.4 kB)</span><span class="spacer"></span><span>Free space: 412 GB</span></div>
        </div>
      </div>
    </div>`;
  }

  /* ---------------- shell pieces ---------------- */
  function shell(now = "Sat 31 Oct  15:42") {
    const tray = `${I("wifi")}${I("volume")}${I("battery")}`;
    const ws = `<div class="ws"><i class="cur"></i><i></i><i></i></div>`;
    const top = `<div class="topbar" data-role="shell"><span class="seg">${ws}</span><span class="clock">${now}</span><span class="spacer"></span><span class="seg on">${tray}</span></div>`;
    const apps = [["files", "folder", 1], ["web", "computer", 1], ["mail", "mail"], ["music", "volume"], ["photos", "image"], ["text", "file", 1], ["term", null], ["settings", "settings"]];
    const ai = ([k, ic], cls = "") => `<div class="appicon ${k} ${cls}">${ic ? I(ic) : `<span class="glyph">&gt;_</span>`}</div>`;
    const dock = `<div class="dock" data-role="shell">${apps.map((a) => ai(a, a[2] ? "run" : "")).join("")}<div class="sep"></div>${ai(["store", "add"])}<div class="appicon grid-btn">${I("grid")}</div></div>`;
    return top + dock;
  }

  function quickSettings(style) {
    return `<div class="qs" data-role="float" style="${style}">
      <div class="qs-head"><div class="avatar photo"></div><div class="grow"><div style="font-weight:650">Tarik</div><div class="caption muted">87% · 6 h 20 min left</div></div>
        <span class="btn icon flat">${I("settings")}</span><span class="btn icon flat">${I("lock")}</span><span class="btn icon flat">${I("power")}</span></div>
      <div class="srow">${I("volume")}<div class="slider" style="--v:62%"><div class="fill"></div><div class="thumb"></div></div></div>
      <div class="srow">${I("brightness")}<div class="slider" style="--v:78%"><div class="fill"></div><div class="thumb"></div></div></div>
      <div class="tiles">
        ${tile("wifi", "Wi-Fi", "Lagoon 5G", true)}${tile("bluetooth", "Bluetooth", "2 devices", true)}
        ${tile("night", "Night Light", "Until 07:00")}${tile("palette", "Dark Style", "Off")}
        ${tile("battery", "Power Mode", "Balanced", true)}${tile("bell", "Do Not Disturb", "Off")}
      </div>
    </div>`;
  }
  const tile = (ic, label, sub, on) => `<div class="tile ${on ? "on" : ""}"><div class="t-main">${I(ic)}<div class="grow"><div class="t-label">${label}</div><div class="t-sub">${sub}</div></div></div><div class="t-more">${I("chevron-right")}</div></div>`;

  function notification(style) {
    return `<div class="notif" data-role="float" style="${style}"><div class="appicon mail">${I("mail")}</div><div class="grow"><div class="n-title">Maya Okafor<span class="dim">now</span></div><div class="n-body">Sent the new renders. Can you check the glass edge on the dock before tonight?</div><div class="row-flex" style="margin-top:10px;gap:8px"><span class="btn small">Reply</span><span class="btn small">Mark as Read</span></div></div></div>`;
  }

  /* ---------------- scenes ---------------- */
  const scenes = {};

  scenes.desktop = () => {
    const qsPos = "top:52px;right:14px";
    const nPos = "top:420px;right:14px";
    return `<div class="desktop">
      ${filesWindow("left:70px;top:96px;width:920px;height:620px")}
      ${shell()}
      ${quickSettings(qsPos)}
      ${notification(nPos)}
    </div>`;
  };


  /* ---------------- edge-docked shells ---------------- */
  const appList = [["files", "folder", "Files", 1], ["web", "computer", "Web", 1], ["mail", "mail", "Mail"], ["music", "volume", "Music"], ["photos", "image", "Photos"], ["text", "file", "Text Editor", 1], ["term", null, "Terminal"], ["settings", "settings", "Settings"]];
  const aic = ([k, ic], cls = "") => `<div class="appicon ${k} ${cls}">${ic ? I(ic) : `<span class="glyph">&gt;_</span>`}</div>`;

  function railShell() {
    const apps = appList.map((a, i) => aic(a, a[3] ? (i === 0 ? "run cur" : "run") : "")).join("");
    return `<nav class="rail mat-glass" data-role="shell">
      <div class="rbtn">${I("grid")}</div>
      <div class="wsl">
        <div class="wsm cur"><b class="side" style="left:4px;top:5px;width:26px;height:19px"></b><b style="left:22px;top:10px;width:22px;height:16px"></b><u>1</u></div>
        <div class="wsm"><b style="left:5px;top:4px;width:38px;height:22px"></b><u>2</u></div>
        <div class="wsm"><b style="left:3px;top:6px;width:20px;height:18px"></b><b style="left:25px;top:4px;width:20px;height:14px"></b><u>3</u></div>
        <div class="wsm empty"></div>
      </div>
      <div class="sep"></div>
      ${apps}
      <div class="sep"></div>
      ${aic(["store", "add"])}
      <div class="spacer"></div>
      <div class="tray">${I("wifi")}${I("volume")}${I("battery")}</div>
      <div class="clock">15<br>42<small>31 Oct</small></div>
      <div class="rbtn">${I("power")}</div>
    </nav>`;
  }

  function railOpenShell() {
    const row = (a, i) => `<div class="side-item ${i === 0 ? "active" : ""}">${aic(a)}<span>${a[2]}</span>${a[3] ? `<span class="spacer"></span><span class="dim caption">${i === 0 ? "3 windows" : ""}</span>` : ""}</div>`;
    const running = appList.filter((a) => a[3]);
    const pinned = appList.filter((a) => !a[3]);
    return `<nav class="rail open mat-glass" data-role="shell">
      <div class="entry pill" style="margin-bottom:6px">${I("search")}<span class="dim">Search apps and files</span></div>
      <div class="side-label">Running</div>
      ${running.map(row).join("")}
      <div class="side-label">Pinned</div>
      ${pinned.map((a) => row(a, 9)).join("")}
      <div class="spacer"></div>
      <div class="user"><div class="avatar photo"></div><div class="grow"><div style="font-weight:650">Tarik</div><div class="caption muted">87% · 15:42</div></div><div class="tray-row">${I("wifi")}${I("volume")}${I("power")}</div></div>
    </nav>`;
  }

  function edgeShell() {
    const tasks = [["files", "folder", "Files"], ["text", "file", "notes.md"], ["web", "computer", "Web"]]
      .map((a, i) => `<span class="task ${i === 0 ? "cur" : ""}">${aic(a)}${i === 0 ? `<span>${a[2]}</span>` : ""}</span>`).join("");
    return `<div class="edgebar mat-glass" data-role="shell">
      <span class="seg on">${I("grid")}Activities</span>
      <span class="seg num cur">1</span><span class="seg num">2</span><span class="seg num">3</span>
      <span class="vsep"></span>${tasks}
      <span class="spacer"></span>
      <span class="seg">${I("wifi")}${I("volume")}${I("battery")}</span>
      <span class="seg on">Sat 31 Oct  15:42</span>
    </div>`;
  }

  scenes.rail = () => `<div class="desktop">
      ${filesWindow("left:120px;top:70px;width:920px;height:620px")}
      ${railShell()}
      ${quickSettings("bottom:14px;left:80px")}
    </div>`;
  scenes["rail-open"] = () => `<div class="desktop">
      ${filesWindow("left:312px;top:70px;width:920px;height:620px", true)}
      ${railOpenShell()}
    </div>`;
  scenes.edge = () => `<div class="desktop">
      ${filesWindow("left:70px;top:70px;width:920px;height:620px")}
      ${edgeShell()}
      ${notification("top:48px;right:14px")}
    </div>`;

  scenes.settings = () => {
    const items = [
      sideItem("wifi", "Wi-Fi"), sideItem("bluetooth", "Bluetooth"), sideItem("computer", "Displays"),
      sideItem("volume", "Sound"), sideItem("battery", "Power"), sideItem("palette", "Appearance", true),
      sideItem("bell", "Notifications", false, "2"), sideItem("lock", "Privacy & Security"), sideItem("person", "Users"),
      sideItem("tune", "System"),
    ].join("");
    const acc = ["blue", "teal", "green", "yellow", "orange", "red", "pink", "purple", "slate"];
    const T = window.ONE.tokens.accents;
    const sw = `<div class="swatch wall ${window.ONE.state.accent === "wallpaper" ? "on" : ""}" title="From wallpaper"></div>` + acc.map((a) => `<div class="swatch ${window.ONE.state.accent === a ? "on" : ""}" style="--sw:oklch(.62 ${T[a].chroma} ${T[a].hue})"></div>`).join("");
    const mode = window.ONE.state.mode;
    const styleCard = (m, label) => `<div class="style-card ${m === mode ? "on" : ""}"><div class="sc-prev ${m}"><div class="sc-win"><i></i><i></i><i></i></div></div><div class="sc-label">${label}</div></div>`;
    const groups = [title("Appearance"), spacer, raw(wm())];
    return `<div class="desktop">
      <div class="window" data-role="canvas" style="left:50%;top:50%;width:1180px;height:800px;transform:translate(-50%,-50%)">
        <div class="win-row">
          ${sidebar(`<div class="entry search side-search">${I("search")}<span>Search settings</span></div>` + items, `<span class="btn icon flat">${I("menu")}</span>`, 260)}
          <div class="pane" data-role="canvas">
            ${hb(groups)}
            <div class="under-hb grow scroll"><div class="page">
              <div class="group cards-group"><div class="style-cards">${styleCard("light", "Light")}${styleCard("dark", "Dark")}${styleCard("auto", "Automatic")}</div></div>
              <div class="group-title">Accent color <span class="muted">Used for selection, controls and highlights</span></div>
              <div class="group"><div class="prow"><div class="swatches">${sw}</div></div>
                <div class="prow"><div class="grow"><div class="ptitle">Tint surfaces with accent</div><div class="psub">Subtly colors windows and panels</div></div><div class="switch on"><div class="knob"></div></div></div></div>
              <div class="group-title">Wallpaper</div>
              <div class="group"><div class="prow wall-row">${["dune", "lagoon", "orchid", "moss", "wave"].map((w) => `<div class="wall-thumb ${window.ONE.state.wall === w ? "on" : ""}" style="background-image:url(assets/wallpapers/${w}-${mode === "dark" ? "dark" : "light"}.webp)"></div>`).join("")}<div class="wall-thumb add">${I("add")}</div></div></div>
              <div class="group-title">Interface</div>
              <div class="group">
                <div class="prow"><div class="lead accent">${I("file")}</div><div class="grow"><div class="ptitle">Interface font</div><div class="psub">Used across apps and shell</div></div><div class="trail"><span>${tok().font.ui} 11</span>${I("chevron-right")}</div></div>
                <div class="prow"><div class="lead">${I("grid")}</div><div class="grow"><div class="ptitle">Density</div><div class="psub">Spacing of controls and lists</div></div><div class="tabs"><span class="tab">Compact</span><span class="tab active">Default</span><span class="tab">Roomy</span></div></div>
                <div class="prow"><div class="lead">${I("tune")}</div><div class="grow"><div class="ptitle">Transparency</div></div><div class="slider" style="--v:40%;max-width:220px"><div class="fill"></div><div class="thumb"></div></div></div>
                <div class="prow"><div class="lead">${I("refresh")}</div><div class="grow"><div class="ptitle">Reduce motion</div></div><div class="switch"><div class="knob"></div></div></div>
                <div class="prow"><div class="lead">${I("palette")}</div><div class="grow"><div class="ptitle">Theme legacy apps</div><div class="psub">GTK 3, Qt 5/6, Electron and Firefox</div></div><div class="switch on"><div class="knob"></div></div></div>
              </div>
            </div></div>
          </div>
        </div>
      </div>
    </div>`;
  };

  scenes.login = () => {
    return `<div class="desktop login-scene">
      <div class="login-veil"></div>
      <div class="login-clock"><div class="lc-date">Saturday, 31 October</div><div class="lc-time">15:42</div></div>
      <div class="login-card" data-role="dialog">
        <div class="avatar photo" style="width:96px;height:96px"></div>
        <div class="title2">Tarik</div>
        <div class="entry focus pill login-entry"><span class="val">••••••••</span><span class="caret"></span><span class="spacer"></span><span class="btn icon suggested small round">${I("forward")}</span></div>
        <div class="caption muted">Fingerprint or password</div>
      </div>
      <div class="login-users" data-role="osd"><div class="avatar" style="--h:150"></div><div class="avatar" style="--h:300"></div><span class="btn icon flat">${I("add")}</span></div>
      <div class="login-bar">
        <span class="btn icon login-btn" data-role="osd">${I("person")}</span>
        <span class="btn login-btn" data-role="osd">${I("computer")}<span>oneShell</span>${I("chevron-down")}</span>
        <span class="spacer"></span>
        <span class="btn icon login-btn" data-role="osd">${I("wifi")}</span>
        <span class="btn icon login-btn" data-role="osd">${I("battery")}</span>
        <span class="btn icon login-btn" data-role="osd">${I("power")}</span>
      </div>
    </div>`;
  };

  scenes.components = () => {
    const spec = tok();
    const sw = (v, n) => `<div class="cswatch"><div class="cs-chip" style="background:var(${v})"></div><span class="caption">${n}</span></div>`;
    const type = [["display", "Aa"], ["title1", "Title 1"], ["title2", "Title 2"], ["title3", "Title 3"], ["heading", "Heading"], ["body", "Body text, 14/20"], ["caption", "Caption 12/16"]];
    return `<div class="desktop">
      <div class="window sheet" data-role="canvas" style="left:40px;top:36px;right:40px;bottom:36px">
        ${hb([title(spec.name, spec.tagline), spacer, raw(wm())], { sep: true })}
        <div class="under-hb grow scroll sheet-body">
          <div class="sheet-col">
            <div class="sec-label">Buttons</div>
            <div class="row-flex wrap"><span class="btn">Default</span><span class="btn hover">Hover</span><span class="btn suggested">Suggested</span><span class="btn destructive">Delete</span><span class="btn flat">Flat</span><span class="btn icon">${I("add")}</span><span class="btn icon flat">${I("more")}</span></div>
            <div class="row-flex wrap"><span class="btn pill suggested">${I("send")}Send</span><div class="linked"><span class="btn icon toggled">${I("grid")}</span><span class="btn icon">${I("list")}</span></div><span class="btn focus-ring">Focused</span><span class="btn small">Small</span></div>
            <div class="sec-label">Inputs</div>
            <div class="entry">${I("search")}<span>Search</span></div>
            <div class="entry focus"><span class="val">Frosted glass</span><span class="caret"></span></div>
            <div class="sec-label">Selection</div>
            <div class="row-flex wrap" style="gap:18px"><div class="switch on"><div class="knob"></div></div><div class="switch"><div class="knob"></div></div><div class="check on"></div><div class="check"></div><div class="radio on"></div><div class="radio"></div></div>
            <div class="slider" style="--v:64%"><div class="fill"></div><div class="thumb"></div></div>
            <div class="progress" style="--v:38%"></div>
            <div class="row-flex wrap"><div class="tabs"><span class="tab active">Overview</span><span class="tab">Files</span><span class="tab">Activity</span></div></div>
            <div class="row-flex wrap"><span class="chip on">${I("check")}Images</span><span class="chip">Documents</span><span class="chip">Audio</span></div>
          </div>
          <div class="sheet-col">
            <div class="sec-label">Lists</div>
            <div class="group">
              <div class="prow"><div class="lead accent">${I("wifi")}</div><div class="grow"><div class="ptitle">Wi-Fi</div><div class="psub">Connected to Lagoon 5G</div></div><div class="switch on"><div class="knob"></div></div></div>
              <div class="prow"><div class="lead">${I("bluetooth")}</div><div class="grow"><div class="ptitle">Bluetooth</div><div class="psub">2 devices</div></div><div class="trail">${I("chevron-right")}</div></div>
              <div class="prow"><div class="lead">${I("night")}</div><div class="grow"><div class="ptitle">Night Light</div></div><div class="check on"></div></div>
            </div>
            <div class="sec-label">Menu & overlays</div>
            <div class="overlay-stage">
              <div class="popover static" data-role="float">
                <div class="menu-item">${I("copy")}Copy<span class="accel">Ctrl C</span></div>
                <div class="menu-item hl">${I("save")}Save As…<span class="accel">Shift Ctrl S</span></div>
                <div class="menu-item">${I("refresh")}Reload</div>
                <div class="menu-sep"></div>
                <div class="menu-item">${I("trash")}Move to Trash<span class="accel">Del</span></div>
              </div>
              <div class="tooltip static" data-role="osd">Open in new window</div>
              <div class="toast static" data-role="osd">File moved to Trash<span class="btn small flat accent-text">Undo</span></div>
            </div>
          </div>
          <div class="sheet-col">
            <div class="sec-label">Color</div>
            <div class="cswatches">
              ${sw("--c-accent", "Accent")}${sw("--c-container", "Container")}${sw("--c-accent-soft", "Soft")}${sw("--c-desktop", "Desktop")}
              ${sw("--c-canvas", "Canvas")}${sw("--c-sidebar", "Sidebar")}${sw("--c-surface", "Surface")}${sw("--c-float", "Float")}
              ${sw("--c-success", "Success")}${sw("--c-warning", "Warning")}${sw("--c-danger", "Danger")}${sw("--c-text", "Text")}
            </div>
            <div class="sec-label">Type · ${spec.font.ui}</div>
            <div class="type-ramp">${type.map(([k, t]) => `<div class="${k === "body" ? "" : k}" ${k === "display" ? 'style="font-size:var(--fs-display);line-height:var(--lh-display);font-weight:var(--title-weight)"' : ""}>${t}</div>`).join("")}</div>
            <div class="sec-label">Shape & depth</div>
            <div class="shape-row">
              ${["window", "container", "control", "small"].map((r) => `<div class="shape" style="border-radius:var(--r-${r})"><span class="caption">${r}<br><b>${spec.shape[r]}px</b></span></div>`).join("")}
            </div>
            <div class="sec-label">Icons · ${spec.icons}</div>
            <div class="icon-row">${["folder", "home", "search", "settings", "wifi", "bluetooth", "volume", "battery", "person", "trash", "image", "palette"].map((n) => I(n, "lg")).join("")}</div>
          </div>
        </div>
      </div>
    </div>`;
  };

  scenes.apps = () => {
    const code = [
      ["k", "import"], [" ", " "], ["t", "{ Window, HeaderBar }"], [" ", " "], ["k", "from"], [" ", " "], ["s", '"@one/ui"'], ["\n"],
      ["\n"],
      ["c", "// one window, one token set, every toolkit"], ["\n"],
      ["k", "export function"], [" ", " "], ["f", "Editor"], [" ", "() {"], ["\n"],
      [" ", "  "], ["k", "const"], [" ", " theme = "], ["f", "useTokens"], [" ", "("], [" ", ");"], ["\n"],
      [" ", "  "], ["k", "return"], [" ", " ("], ["\n"],
      [" ", "    <"], ["t", "Window"], [" ", " "], ["a", "radius"], [" ", "={theme.shape.window} "], ["a", "material"], [" ", "="], ["s", '"solid"'], [" ", ">"], ["\n"],
      [" ", "      <"], ["t", "HeaderBar"], [" ", " "], ["a", "title"], [" ", "="], ["s", '"notes.md"'], [" ", " />"], ["\n"],
      [" ", "      <"], ["t", "Editor"], [" ", " "], ["a", "font"], [" ", "={theme.font.mono} "], ["a", "size"], [" ", "={"], ["n", "14"], [" ", "} />"], ["\n"],
      [" ", "    </"], ["t", "Window"], [" ", ">"], ["\n"],
      [" ", "  );"], ["\n"], [" ", "}"], ["\n"],
      ["\n"],
      ["c", "// generated for gtk4, qt6, kde and gdm"], ["\n"],
      ["k", "export const"], [" ", " surfaces = {"], ["\n"],
      [" ", "  "], ["a", "canvas"], [" ", ": "], ["s", '"solid"'], [" ", ","], ["\n"],
      [" ", "  "], ["a", "sidebar"], [" ", ": "], ["s", '"solid"'], [" ", ","], ["\n"],
      [" ", "  "], ["a", "float"], [" ", ": "], ["s", '"glass"'], [" ", ",  "], ["c", "// menus, osd, dock"], ["\n"],
      [" ", "  "], ["a", "radius"], [" ", ": ["], ["n", "18"], [" ", ", "], ["n", "14"], [" ", ", "], ["n", "10"], [" ", ", "], ["n", "6"], [" ", "],"], ["\n"],
      [" ", "};"], ["\n"],
    ];
    const lines = code.map(([k, t]) => (k === "\n" ? "\n" : `<span class="syn-${k === " " ? "p" : k}">${(t || "").replace(/</g, "&lt;")}</span>`)).join("").split("\n");
    const editor = lines.map((l, i) => `<div class="code-line ${i === 6 ? "cur" : ""}"><span class="ln">${i + 1}</span><span>${l || " "}</span></div>`).join("");
    const editorHb = [`<span class="btn icon flat">${I("documents")}</span><span class="btn icon flat">${I("add")}</span>`, title("notes.md", "~/Projects"), spacer, `<span class="btn flat suggested-soft">${I("save")}Save</span><span class="btn icon flat hover">${I("menu")}</span>`, raw(wm())];
    const termLines = [
      `<span class="t-g">tarik@one</span>:<span class="t-b">~/Projects</span>$ one-theme apply`,
      `<span class="t-d">  gtk4   </span> libadwaita stylesheet      <span class="t-g">ok</span>`,
      `<span class="t-d">  gtk3   </span> adw-gtk3 overrides         <span class="t-g">ok</span>`,
      `<span class="t-d">  qt6    </span> Kvantum + qt6ct palette    <span class="t-g">ok</span>`,
      `<span class="t-d">  kde    </span> color scheme + decoration  <span class="t-g">ok</span>`,
      `<span class="t-d">  gdm    </span> greeter theme              <span class="t-y">needs root</span>`,
      `<span class="t-d">  firefox</span> userChrome.css             <span class="t-g">ok</span>`,
      `<span class="t-g">tarik@one</span>:<span class="t-b">~/Projects</span>$ <span class="t-cursor"></span>`,
    ].map((l) => `<div>${l}</div>`).join("");
    return `<div class="desktop">
      <div class="window backdrop term-win" data-role="canvas" style="left:930px;top:440px;width:610px;height:340px">
        ${hb([`<span class="btn icon flat">${I("add")}</span>`, title("tarik@one: ~/Projects"), spacer, `<span class="btn icon flat">${I("search")}</span><span class="btn icon flat">${I("menu")}</span>`, raw(wm())])}
        <div class="under-hb grow term-body">${termLines}</div>
      </div>
      <div class="window editor-win" data-role="canvas" style="left:60px;top:70px;width:830px;height:620px">
        ${hb(editorHb, { sep: true })}
        <div class="under-hb grow code">${editor}</div>
        <div class="statusbar"><span>Markdown</span><span>Spaces: 2</span><span class="spacer"></span><span>Ln 7, Col 24</span></div>
        <div class="popover" data-role="float" style="right:60px;top:calc(var(--h-headerbar) - 2px)">
          <div class="menu-item">${I("add")}New Window<span class="accel">Ctrl N</span></div>
          <div class="menu-item hl">${I("save")}Save As…<span class="accel">Shift Ctrl S</span></div>
          <div class="menu-item">${I("search")}Find and Replace…<span class="accel">Ctrl H</span></div>
          <div class="menu-sep"></div>
          <div class="menu-item">${I("palette")}Preferences<span class="accel">Ctrl ,</span></div>
          <div class="menu-item">${I("documents")}About Text Editor</div>
        </div>
      </div>
      <div class="dialog" data-role="dialog" style="position:absolute;left:960px;top:110px">
        <div class="d-body"><div class="title3" style="margin-bottom:8px">Save changes?</div><div class="muted">“budget.ods” has unsaved changes. Changes which are not saved will be permanently lost.</div></div>
        <div class="d-actions"><span class="btn">Cancel</span><span class="btn destructive">Discard</span><span class="btn suggested">Save</span></div>
      </div>
      ${shell()}
    </div>`;
  };

  window.oneRender = (one) => (scenes[one.state.scene] || scenes.desktop)(one);
})();
