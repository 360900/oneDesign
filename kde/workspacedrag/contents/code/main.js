// KWin holds the pointer while it moves a window, so the rail sees no hover. This does the rail's hover
// for it: the rail publishes where its thumbnails are, and KWin takes the moved window along on a switch.
const READ_ZONES = 'var out = []; panels().forEach(function (p) { p.widgets().forEach(function (w) {'
    + ' if (w.type == "org.onedesign.rail") { w.currentConfigGroup = ["General"]; out.push(w.readConfig("workspaceZones")); }'
    + ' }); }); print(JSON.stringify(out));';

let dock = null;
let zones = [];
let target = -1;

const dwell = new QTimer();
dwell.interval = 350;
dwell.singleShot = true;
dwell.timeout.connect(() => {
    const desktop = workspace.desktops[target];
    if (desktop) workspace.currentDesktop = desktop;
});

function contains(g, x, y) {
    return x >= g.x && x < g.x + g.width && y >= g.y && y < g.y + g.height;
}

// An auto-hidden panel keeps its place while it is out of sight, so a hidden one does not count
function dockAt(pos) {
    return workspace.stackingOrder.find(w => w.dock && !w.hidden && contains(w.frameGeometry, pos.x, pos.y)) || null;
}

// KWin shows an auto-hidden panel for a pointer at the screen edge, but not while it moves a window.
// The pointer at the edge of a hidden dock asks the rail to show itself until it leaves the dock.
let revealed = null;

function hiddenDockAtEdge(pos) {
    return workspace.stackingOrder.find(w => {
        if (!w.dock || !w.hidden || !contains(w.frameGeometry, pos.x, pos.y)) return false;
        const g = w.frameGeometry;
        const s = workspace.clientArea(KWin.FullScreenArea, w);
        return (g.x <= s.x && pos.x <= s.x) || (g.x + g.width >= s.x + s.width && pos.x >= s.x + s.width - 1);
    }) || null;
}

function reveal(window) {
    const was = !!revealed;
    revealed = window;
    if (was === !!window) return;
    callDBus("org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript",
        'panels().forEach(function (p) { p.widgets().forEach(function (w) {'
        + ' if (w.type == "org.onedesign.rail") { w.currentConfigGroup = ["General"]; w.writeConfig("revealForMove", ' + !!window + '); }'
        + ' }); });');
}

// The rail's thumbnails are in panel coordinates and stay put when the panel changes length
function zoneAt(pos) {
    if (!dock) return -1;
    const g = dock.frameGeometry;
    for (const rail of zones) {
        if (rail.width !== g.width) continue;
        const i = rail.rects.findIndex(r => contains({ x: r[0], y: r[1], width: r[2], height: r[3] }, pos.x - g.x, pos.y - g.y));
        if (i >= 0) return i;
    }
    return -1;
}

function aim(i) {
    if (i === target) return;
    target = i;
    dwell.stop();
    if (i >= 0 && workspace.desktops[i] !== workspace.currentDesktop) dwell.start();
}

function readZones() {
    callDBus("org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript", READ_ZONES, reply => {
        zones = [];
        try {
            zones = JSON.parse(reply).filter(z => z).map(z => JSON.parse(z));
        } catch (e) {
            return;
        }
        aim(zoneAt(workspace.cursorPos));
    });
}

function follow() {
    const pos = workspace.cursorPos;
    if (!revealed) reveal(hiddenDockAtEdge(pos));
    else if (!contains(revealed.frameGeometry, pos.x, pos.y)) reveal(null);
    const under = dockAt(pos);
    if (under !== dock) {
        dock = under;
        zones = [];
        if (dock) readZones();
    }
    aim(zoneAt(pos));
}

function watch(window) {
    let moving = false;
    window.interactiveMoveResizeStarted.connect(() => {
        if (!window.move) return;
        moving = true;
        workspace.cursorPosChanged.connect(follow);
        follow();
    });
    window.interactiveMoveResizeFinished.connect(() => {
        if (!moving) return;
        moving = false;
        workspace.cursorPosChanged.disconnect(follow);
        dock = null;
        aim(-1);
        reveal(null);
    });
}

workspace.windowList().forEach(watch);
workspace.windowAdded.connect(watch);

// A drag that leaves the rail becomes a move of the window itself, so it snaps and tiles like any
// other: the rail names the window in its grabWindow setting, followed by the app's other windows,
// and invokes this shortcut, which has no keys of its own. KWin starts the move from the window's
// center, so the window goes there first. The others go along to each desktop the move goes to.
const READ_GRAB = 'var out = ""; panels().forEach(function (p) { p.widgets().forEach(function (w) {'
    + ' if (w.type == "org.onedesign.rail") { w.currentConfigGroup = ["General"]; var g = w.readConfig("grabWindow"); if (g) out = g; }'
    + ' }); }); print(out);';

function plainId(id) {
    return String(id).replace(/[{}]/g, "");
}

function windowById(id) {
    return workspace.windowList().find(w => plainId(w.internalId) === plainId(id)) || null;
}

function toCurrentDesktop(window) {
    if (!window.onAllDesktops && (window.desktops.length !== 1 || window.desktops[0] !== workspace.currentDesktop))
        window.desktops = [workspace.currentDesktop];
}

// KWin takes the moved window along on a desktop switch; this takes the rest. It stops with the
// move, or at the first switch after a move that never started.
function carry(window, along) {
    if (!along.length) return;
    const follow = () => {
        if (!window.move) { done(); return; }
        along.forEach(w => { if (!w.deleted) toCurrentDesktop(w); });
    };
    const done = () => {
        workspace.currentDesktopChanged.disconnect(follow);
        window.interactiveMoveResizeFinished.disconnect(done);
    };
    workspace.currentDesktopChanged.connect(follow);
    window.interactiveMoveResizeFinished.connect(done);
}

function startMove(window, along) {
    const c = workspace.cursorPos;
    const g = window.frameGeometry;
    window.frameGeometry = { x: c.x - g.width / 2, y: c.y - g.height / 2, width: g.width, height: g.height };
    workspace.activeWindow = window;
    carry(window, along);
    workspace.slotWindowMove();
}

function grab(ids) {
    const window = windowById(ids[0]);
    if (!window || !window.moveable) return;
    const along = ids.slice(1).map(windowById).filter(w => w && w !== window);
    if (window.minimized) window.minimized = false;
    if (!window.onAllDesktops && window.desktops.indexOf(workspace.currentDesktop) < 0) window.desktops = [workspace.currentDesktop];
    // the others come to this desktop too, behind the moved one
    along.forEach(toCurrentDesktop);
    // a maximized window takes its normal size back first, which it does a moment later
    const settle = window.maximizeMode !== 0;
    if (settle) window.setMaximize(false, false);
    if (!settle) { startMove(window, along); return; }
    const later = new QTimer();
    later.interval = 60;
    later.singleShot = true;
    later.timeout.connect(() => startMove(window, along));
    later.start();
}

registerShortcut("onedesign-grab-window", "oneDesign: move the window dragged off the rail", "", () => {
    callDBus("org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript", READ_GRAB, reply => {
        const ids = String(reply || "").trim().split(/\s+/).filter(i => i);
        if (ids.length) grab(ids);
    });
});
