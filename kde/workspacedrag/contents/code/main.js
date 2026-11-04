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

function dockAt(pos) {
    return workspace.stackingOrder.find(w => w.dock && contains(w.frameGeometry, pos.x, pos.y)) || null;
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
    });
}

workspace.windowList().forEach(watch);
workspace.windowAdded.connect(watch);
