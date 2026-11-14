import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.kicker as Kicker
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.workspace.dbus as DBus
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

// The rail: workspace thumbnails on top, pinned and running apps below.
// Items keep their own size and stack from the top, so the panel never spreads them.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    // Brings an auto-hidden panel back while an app asks for attention, as KDE's task manager does, and
    // holds it while a window moved by KWin is at its edge (see the workspacedrag script)
    Plasmoid.status: Plasmoid.configuration.revealForMove ? PlasmaCore.Types.RequiresAttentionStatus
        : appModel.anyTaskDemandsAttention && Plasmoid.configuration.unhideOnAttention
        ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.PassiveStatus

    readonly property bool dark: Kirigami.Theme.textColor.hsvValue > 0.5
    readonly property int tile: Plasmoid.configuration.tileSize
    readonly property color fill: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.38)
    readonly property color fillHover: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0.2, 0.28, 0.4, 0.2)
    readonly property int gap: 6
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color fillPressed: Qt.tint(fillHover, Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.45 : 0.30))
    // app tiles (tokens: rail.tile). Focused, or open as a box, a tile is the canvas surface
    // (Plasma's Window color); hover and press lay a tint over it.
    readonly property color tileLifted: Qt.tint(fill, Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.94))
    readonly property color tileHover: dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color tilePressed: Qt.rgba(accent.r, accent.g, accent.b, 0.25)
    readonly property int tileHoverDuration: 120 // motion.fast

    // shared with Task, TaskMenu and TaskToolTip
    readonly property alias tasksModel: appModel
    readonly property alias virtualDesktopInfo: vdi
    readonly property alias activityInfo: activityInfo
    readonly property alias mpris2Source: mpris2Source
    readonly property var pulseAudio: pulseLoader.item
    readonly property int normalVolume: pulseLoader.item ? pulseLoader.item.normalVolume : 65536
    readonly property bool windowViewAvailable: windowViewWatcher.registered
    property Item toolTipOpenedByClick: null
    property bool menuOpen: false
    // the desktop an app tile drag started on: the app column stays on it while the drag
    // switches desktops, so the dragged tile keeps its place. null when no drag runs.
    // the grouped app whose box is open over the apps around it, and the span it covers in the
    // app column; the apps under it step aside
    property Item stackTask: null
    readonly property real stackTop: stackTask ? stackTask.y - (stackTask.growUp ? stackTask.reveal : 0) : 0
    readonly property real stackBottom: stackTask ? stackTask.y + stackTask.height + (stackTask.growUp ? 0 : stackTask.reveal) : 0

    TaskManager.VirtualDesktopInfo { id: vdi }
    TaskManager.ActivityInfo { id: activityInfo }
    Mpris.Mpris2Model { id: mpris2Source }
    Loader { id: pulseLoader; source: "PulseAudio.qml" }
    DBus.DBusServiceWatcher {
        id: windowViewWatcher
        busType: DBus.BusType.Session
        watchedService: "org.kde.KWin.Effect.WindowView1"
    }

    // Every window, any desktop: feeds the thumbnails
    TaskManager.TasksModel {
        id: winModel
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false
        filterNotMinimized: false
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortLastActivated
    }

    // Pinned launchers merged with their running windows: feeds the app column.
    // Set up like KDE's icons-only task manager.
    TaskManager.TasksModel {
        id: appModel
        readonly property bool manual: sortMode === TaskManager.TasksModel.SortManual
        virtualDesktop: vdi.currentDesktop
        activity: activityInfo.currentActivity
        screenGeometry: Plasmoid.containment.screenGeometry
        filterByVirtualDesktop: Plasmoid.configuration.showOnlyCurrentDesktop
        filterByScreen: Plasmoid.configuration.showOnlyCurrentScreen
        filterByActivity: Plasmoid.configuration.showOnlyCurrentActivity
        filterNotMinimized: Plasmoid.configuration.showOnlyMinimized
        hideActivatedLaunchers: true
        groupMode: Plasmoid.configuration.groupingStrategy === 0 ? TaskManager.TasksModel.GroupDisabled : TaskManager.TasksModel.GroupApplications
        groupingAppIdBlacklist: Plasmoid.configuration.groupingAppIdBlacklist
        groupingLauncherUrlBlacklist: Plasmoid.configuration.groupingLauncherUrlBlacklist
        sortMode: [TaskManager.TasksModel.SortDisabled, TaskManager.TasksModel.SortManual, TaskManager.TasksModel.SortAlpha,
                   TaskManager.TasksModel.SortVirtualDesktop, TaskManager.TasksModel.SortActivity,
                   TaskManager.TasksModel.SortWindowPositionHorizontal][Plasmoid.configuration.sortingStrategy] ?? TaskManager.TasksModel.SortManual
        // Running apps take their pin's place unless pins are kept separate
        separateLaunchers: true
        launchInPlace: manual && !Plasmoid.configuration.separateLaunchers
        launcherList: Plasmoid.configuration.launchers
        onGroupingAppIdBlacklistChanged: Plasmoid.configuration.groupingAppIdBlacklist = groupingAppIdBlacklist
        onGroupingLauncherUrlBlacklistChanged: Plasmoid.configuration.groupingLauncherUrlBlacklist = groupingLauncherUrlBlacklist
    }

    // Pin, unpin and reorder are written back so they survive a restart
    Connections {
        target: appModel
        function onLauncherListChanged() {
            const l = appModel.launcherList;
            if (JSON.stringify(l) !== JSON.stringify(Plasmoid.configuration.launchers)) Plasmoid.configuration.launchers = l;
        }
    }
    readonly property string pinText: i18n("Pin to Rail")
    readonly property string unpinText: i18n("Unpin from Rail")

    // ---- helpers shared with the task items, after KDE's TaskTools.js
    function foreachChildTask(callback, idx) {
        const n = appModel.rowCount(idx);
        if (n > 0) for (let i = 0; i < n; ++i) callback(appModel.index(i, 0, idx));
        else callback(idx);
    }
    function groupTopTask(list, role) {
        let top = -1, res = undefined;
        for (const idx of list) {
            const v = appModel.data(idx, role);
            if (v !== undefined && v > top) { top = v; res = idx; }
        }
        return res;
    }
    function isApplication(url) {
        const u = url.toString();
        return u.startsWith("applications:") || u.endsWith(".desktop");
    }
    function windowsHovered(winIds, hovered) {
        if (!Plasmoid.configuration.highlightWindows) return;
        DBus.SessionBus.asyncCall({ service: "org.kde.KWin.HighlightWindow", path: "/org/kde/KWin/HighlightWindow",
            iface: "org.kde.KWin.HighlightWindow", member: "highlightWindows",
            arguments: [hovered ? winIds.map(String) : []], signature: "(as)" });
    }
    // ---- dragging apps and windows: app tiles, window entries and window previews
    // A drag is a platform drag from a source that outlives the tiles (the rail's drag card), so the
    // app column can follow the desktop the drag switches to. The rail's drop area does the rest.
    readonly property string windowMime: "application/x-onedesign-window"
    // { kind: "app" | "window", winIds, launcher, icon, fromDesktop, startRow }; null when no drag runs
    property var dragSpec: null
    property var dragActiveWin: null // the window that had focus when the drag started
    property Item incomingTask: null // an app of the same kind the drag hovers: it opens with a slot
    property int incomingSlot: -1
    function setIncoming(t, slot) {
        incomingTask = t;
        incomingSlot = t ? slot : -1;
    }

    function winIdOf(index) {
        const ids = winModel.data(index, TaskManager.AbstractTasksModel.WinIdList) || [];
        return ids.length ? String(ids[0]) : null;
    }
    function activeWinId() {
        const a = winModel.activeTask;
        return a && a.valid ? winIdOf(a) : null;
    }
    function launcherOf(index) {
        return String(appModel.data(index, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon) || "");
    }
    // the app column row holding the dragged windows, or the dragged launcher
    function dragRow(s) {
        const R = TaskManager.AbstractTasksModel;
        for (let i = 0; i < appModel.count; ++i) {
            const index = appModel.makeModelIndex(i);
            if (!s.winIds.length) {
                if (appModel.data(index, R.IsLauncher) === true && launcherOf(index) === s.launcher) return i;
                continue;
            }
            const n = appModel.rowCount(index);
            const kids = n > 0 ? [...Array(n).keys()].map(c => appModel.makeModelIndex(i, c)) : [index];
            if (kids.some(k => (appModel.data(k, R.WinIdList) || []).some(id => s.winIds.indexOf(String(id)) >= 0))) return i;
        }
        return -1;
    }
    function dragSwitched(s) {
        return String(vdi.currentDesktop) !== String(s.fromDesktop);
    }
    // takes back a reorder of the dragged app, when the drag ends somewhere else
    function restoreOrder(s) {
        if (!s || s.kind !== "app" || !appModel.manual || dragSwitched(s) || s.startRow < 0) return;
        const row = dragRow(s);
        const to = Math.max(0, Math.min(appModel.count - 1, s.startRow));
        if (row >= 0 && row !== to) appModel.move(row, to);
    }

    // Starts a drag once its card is drawn. spec: kind, winIds, launcher. stillHeld tells whether
    // the button is still down by then.
    function startDrag(spec, icon, title, stillHeld) {
        const rail = fullRepresentationItem;
        if (!rail || dragSpec) return;
        rail.dragCard.icon = icon;
        rail.dragCard.title = title || "";
        rail.dragCard.grabToImage(result => {
            let held = false;
            try { held = stillHeld(); } catch (e) {} // the tile may be gone by now
            if (!held) return;
            beginDrag(Object.assign({ icon: icon }, spec));
            rail.dragCard.Drag.imageSource = result.url;
            rail.dragCard.Drag.active = true; // runs until the drop
        });
    }
    // for drags with their own source (window previews in a tooltip)
    function beginDrag(spec) {
        cancelHighlightWindows();
        dragActiveWin = activeWinId();
        spec.fromDesktop = vdi.currentDesktop;
        spec.startRow = spec.kind === "app" ? dragRow(spec) : -1;
        dragSpec = spec;
    }
    // dropAction is what the drop target did: nothing when the drag ended off the rail or was cancelled
    function finishDrag(dropAction) {
        const s = dragSpec;
        if (!s) return;
        if (dropAction === Qt.IgnoreAction) {
            // off the rail: after a desktop switch the windows come along, else a reorder is taken back
            if (dragSwitched(s)) moveWindows(s.winIds, vdi.currentDesktop, true);
            else restoreOrder(s);
        }
        if (s.kind === "app") appModel.syncLaunchers(); // move() alone does not touch the launcher list
        if (fullRepresentationItem) fullRepresentationItem.dragDesktop = -1;
        setIncoming(null, -1);
        dragSpec = null;
        dragActiveWin = null;
    }

    // Puts windows at a place in their app's group, once they have joined it (a move to this
    // desktop arrives a little later)
    property var pendingPlace: null
    function placeWindows(winIds, launcher, slot) {
        pendingPlace = { winIds: winIds.map(String), launcher: launcher, slot: slot, tries: 0 };
        placeTimer.restart();
    }
    Timer {
        id: placeTimer
        interval: 60
        repeat: true
        onTriggered: {
            const p = root.pendingPlace;
            if (!p || ++p.tries > 25 || root.tryPlace(p)) { root.pendingPlace = null; stop(); }
        }
    }
    function tryPlace(p) {
        const R = TaskManager.AbstractTasksModel;
        for (let i = 0; i < appModel.count; ++i) {
            const g = appModel.makeModelIndex(i);
            if (appModel.data(g, R.IsGroupParent) !== true || launcherOf(g) !== p.launcher) continue;
            const rowOf = id => {
                for (let c = 0; c < appModel.rowCount(g); ++c)
                    if ((appModel.data(appModel.makeModelIndex(i, c), R.WinIdList) || []).some(w => String(w) === id)) return c;
                return -1;
            };
            if (p.winIds.some(id => rowOf(id) < 0)) return false;
            p.winIds.forEach((id, k) => {
                const from = rowOf(id);
                const to = Math.min(appModel.rowCount(g) - 1, p.slot + k);
                if (from !== to) appModel.move(from, to, g);
            });
            return true;
        }
        return false;
    }

    // Moves windows onto one desktop and goes there, keeping their focus: the one that had focus has
    // it there too, the others land behind the window last focused there, or take focus when nothing
    // there had it. keepAll leaves windows that are on all desktops there.
    function moveWindows(winIds, deskId, keepAll) {
        if (deskId === undefined || deskId === null) return;
        const want = winIds.map(String);
        const moved = [];
        for (let i = 0; i < winModel.count; ++i) { // least recently used last, as winModel sorts
            const index = winModel.makeModelIndex(i);
            const id = winIdOf(index);
            if (id === null || want.indexOf(id) < 0) continue;
            if (keepAll && winModel.data(index, TaskManager.AbstractTasksModel.IsOnAllVirtualDesktops) === true) continue;
            const vds = winModel.data(index, TaskManager.AbstractTasksModel.VirtualDesktops) || [];
            if (vds.length === 1 && String(vds[0]) === String(deskId)) continue; // already there
            winModel.requestVirtualDesktops(index, [deskId]);
            moved.push({ id: id, index: index });
        }
        if (!moved.length) {
            if (String(deskId) !== String(vdi.currentDesktop)) switchTo(vdi.desktopIds.indexOf(deskId) + 1);
            return;
        }
        // KWin puts a window it moves first in that desktop's focus chain, so the order is set again
        // by activating, which also goes to the desktop
        const focused = moved.find(w => w.id === String(dragActiveWin));
        const order = moved.filter(w => w !== focused).reverse().map(w => w.index);
        if (focused) order.push(focused.index);
        else {
            const last = lastFocusedOn(deskId, want);
            if (last) order.push(last);
        }
        order.forEach(index => winModel.requestActivate(index));
    }
    // the window used last on a desktop, leaving out some; winModel lists the most recent first
    function lastFocusedOn(deskId, except) {
        const R = TaskManager.AbstractTasksModel;
        for (let i = 0; i < winModel.count; ++i) {
            const index = winModel.makeModelIndex(i);
            const id = winIdOf(index);
            if (id === null || except.indexOf(id) >= 0) continue;
            if (winModel.data(index, R.IsMinimized) === true || winModel.data(index, R.IsOnAllVirtualDesktops) === true) continue;
            const vds = (winModel.data(index, R.VirtualDesktops) || []).map(String);
            if (vds.indexOf(String(deskId)) >= 0) return index;
        }
        return null;
    }
    function cancelHighlightWindows() {
        if (Plasmoid.configuration.highlightWindows) windowsHovered([], false);
    }
    function activateWindowView(winIds) {
        cancelHighlightWindows();
        DBus.SessionBus.asyncCall({ service: "org.kde.KWin.Effect.WindowView1", path: "/org/kde/KWin/Effect/WindowView1",
            iface: "org.kde.KWin.Effect.WindowView1", member: "activate", arguments: [winIds.map(String)], signature: "(as)" });
    }

    // Wheel over the apps, as in KDE: all tasks, the hovered app's windows, or the hovered app's volume
    function wheelTasks(anchor, steps) {
        const mode = Plasmoid.configuration.wheelEnabled;
        if (mode === 0 || steps === 0) return;
        const R = TaskManager.AbstractTasksModel;
        if (mode === 3) {
            if (!anchor || !anchor.audioStreams.length || !pulseAudio) return;
            const loudest = anchor.audioStreams.reduce((l, s) => Math.max(l, s.volume), 0);
            const step = pulseAudio.normalVolume * 5 / 100 * steps;
            for (const s of anchor.audioStreams) {
                const v = Math.max(0, Math.min(pulseAudio.normalVolume, s.volume + (loudest > 0 ? step * s.volume / loudest : step)));
                s.setVolume(v);
                s.setMuted(v === 0);
            }
            return;
        }
        const skip = Plasmoid.configuration.wheelSkipMinimized;
        let list = [];
        for (let i = 0; i < appModel.count; ++i) {
            const idx = appModel.makeModelIndex(i);
            if (appModel.data(idx, R.IsLauncher) || appModel.data(idx, R.IsStartup)) continue;
            const onlyThis = mode === 2 && anchor && anchor.index === i;
            if (mode === 2 && !onlyThis) continue;
            if (appModel.data(idx, R.IsGroupParent)) {
                for (let j = 0; j < appModel.rowCount(idx); ++j) {
                    const c = appModel.makeModelIndex(i, j);
                    if (!skip || !appModel.data(c, R.IsHidden)) list.push(c);
                }
            } else if (!skip || !appModel.data(idx, R.IsHidden)) list.push(idx);
        }
        if (!list.length) return;
        const next = steps < 0;
        const cur = list.findIndex(x => appModel.data(x, R.IsActive) === true);
        let t = 0;
        if (cur >= 0) t = next ? (cur + 1) % list.length : (cur - 1 + list.length) % list.length;
        appModel.requestActivate(list[t]);
    }

    // ---- context menu: Kicker supplies the app's jump list and recent files
    Kicker.SimpleFavoritesModel { id: appEntry }
    Instantiator {
        model: appEntry
        delegate: QtObject {
            required property var model
            Component.onCompleted: root.showTaskMenu(model.actionList || [])
        }
    }
    property Item menuTask: null
    function openTaskMenu(task) {
        menuTask = task;
        const app = task.model.AppId || "";
        appEntry.favorites = [];
        if (!app) { showTaskMenu([]); return; }
        appEntry.favorites = [app.endsWith(".desktop") ? app : app + ".desktop"]; // the Instantiator shows the menu once loaded
    }
    function showTaskMenu(actions) {
        if (!menuTask) return;
        const t = menuTask;
        menuTask = null;
        const m = taskMenuComponent.createObject(root, { r: root, modelIndex: t.modelIndex(), appActions: actions, visualParent: t });
        menuOpen = true;
        m.statusChanged.connect(() => { if (m.status === PlasmaExtras.Menu.Closed) root.menuOpen = false; });
        m.show();
    }
    function triggerAppAction(a) {
        appEntry.trigger(0, a.actionId, a.actionArgument);
    }
    Component { id: taskMenuComponent; TaskMenu {} }

    // Textual list of a group's windows
    function openGroupList(task) {
        const m = groupMenuComponent.createObject(root, { visualParent: task, groupIndex: task.modelIndex() });
        m.refresh();
        m.openRelative();
    }
    Component {
        id: groupMenuComponent
        PlasmaExtras.Menu {
            id: gm
            property var groupIndex
            placement: Plasmoid.location === PlasmaCore.Types.RightEdge ? PlasmaExtras.Menu.LeftPosedTopAlignedPopup
                                                                        : PlasmaExtras.Menu.RightPosedTopAlignedPopup
            onStatusChanged: if (status === PlasmaExtras.Menu.Closed) gm.destroy()
            function refresh() {
                clearMenuItems();
                for (let i = 0; i < appModel.rowCount(groupIndex); ++i) {
                    const c = appModel.index(i, 0, groupIndex);
                    const item = Qt.createQmlObject(`import org.kde.plasma.extras as PlasmaExtras
                        PlasmaExtras.MenuItem {}`, gm);
                    item.text = appModel.data(c, Qt.DisplayRole);
                    item.icon = appModel.data(c, Qt.DecorationRole);
                    item.checkable = true;
                    item.checked = appModel.data(c, TaskManager.AbstractTasksModel.IsActive) === true;
                    item.clicked.connect(() => appModel.requestActivate(c));
                    gm.addMenuItem(item);
                }
            }
        }
    }

    // ---- workspaces, through KWin
    function kwin(path, iface, member, signature, args) {
        DBus.SessionBus.asyncCall({ service: "org.kde.KWin", path: path, iface: iface, member: member, signature: signature, arguments: args });
    }
    function switchTo(n) {
        kwin("/KWin", "org.kde.KWin", "setCurrentDesktop", "(i)", [new DBus.int32(n)]);
    }
    // Workspaces are stacked in one column, so KWin's slide animation runs vertically too
    function stackDesktops() {
        kwin("/VirtualDesktopManager", "org.freedesktop.DBus.Properties", "Set", "(ssv)",
             ["org.kde.KWin.VirtualDesktopManager", "rows", new DBus.variant(Math.max(1, vdi.numberOfDesktops))]);
    }
    Connections {
        target: vdi
        function onNumberOfDesktopsChanged() { root.stackDesktops() }
    }
    function addDesktop() {
        const n = vdi.numberOfDesktops;
        kwin("/VirtualDesktopManager", "org.kde.KWin.VirtualDesktopManager", "createDesktop", "(us)",
             [new DBus.uint32(n), i18n("Desktop %1", n + 1)]);
    }
    // KWin moves the workspace's windows to another one, nothing closes
    function removeDesktop(id) {
        kwin("/VirtualDesktopManager", "org.kde.KWin.VirtualDesktopManager", "removeDesktop", "(s)", [id]);
    }
    function openWorkspaceMenu(ws) {
        workspaceMenuComponent.createObject(root, { visualParent: ws, deskId: ws.deskId }).openRelative();
    }
    Component {
        id: workspaceMenuComponent
        PlasmaExtras.Menu {
            id: wm
            property var deskId
            placement: Plasmoid.location === PlasmaCore.Types.RightEdge ? PlasmaExtras.Menu.LeftPosedTopAlignedPopup
                                                                        : PlasmaExtras.Menu.RightPosedTopAlignedPopup
            onStatusChanged: if (status === PlasmaExtras.Menu.Closed) wm.destroy()
            PlasmaExtras.MenuItem {
                text: i18n("Remove Workspace")
                icon: "list-remove"
                enabled: vdi.numberOfDesktops > 1
                onClicked: root.removeDesktop(wm.deskId)
            }
        }
    }
    // Inset with rounded corners normally; flush and full height while a window is maximized
    property bool maximized: false
    function recountMaximized() {
        let any = false;
        for (let i = 0; i < winModel.count && !any; i++) {
            const ix = winModel.makeModelIndex(i);
            const d = id => winModel.data(ix, id);
            const R = TaskManager.AbstractTasksModel;
            if (d(R.IsWindow) !== true || d(R.IsMinimized) === true || d(R.IsMaximized) !== true) continue;
            const vds = d(R.VirtualDesktops) || [];
            if (d(R.IsOnAllVirtualDesktops) === true || vds.length === 0 || vds.indexOf(vdi.currentDesktop) >= 0) any = true;
        }
        maximized = any;
    }
    Connections {
        target: winModel
        function onCountChanged() { root.recountMaximized() }
        function onDataChanged() { root.recountMaximized() }
        function onModelReset() { root.recountMaximized() }
    }
    Connections {
        target: vdi
        function onCurrentDesktopChanged() { root.recountMaximized() }
    }
    onMaximizedChanged: lengthTimer.restart()
    function panelScript(body) {
        return DBus.SessionBus.asyncCall({ service: "org.kde.plasmashell", path: "/PlasmaShell", iface: "org.kde.PlasmaShell",
            member: "evaluateScript", signature: "(s)",
            arguments: ["var p = panels().filter(function (x) { return x.id == " + Plasmoid.containment.id + "; })[0]; if (p) { " + body + " }"] });
    }

    // ---- full height while a window is maximized. The panel's own settings stay in charge: the rail reads
    // the length you set before it grows and puts exactly that back, and stands down in edit mode and
    // while the panel floats (Plasma then handles maximized windows itself).
    readonly property bool editMode: Plasmoid.containment && Plasmoid.containment.corona ? Plasmoid.containment.corona.editMode === true : false

    // The panel opens a gap between its widgets for anything dragged over it, to place it as a new widget,
    // which pushes the thumbnails away from the pointer. Outside edit mode nothing gets placed on the panel.
    // There is no API for this: KDE's task manager finds the flag by walking up its parents the same way.
    function inhibitPanelDrops() {
        for (let p = root.parent; p; p = p.parent) {
            if (p.appletRequestsInhibitDnD !== undefined) {
                p.appletRequestsInhibitDnD = !editMode;
                return;
            }
        }
    }
    onParentChanged: Qt.callLater(inhibitPanelDrops)
    onEditModeChanged: inhibitPanelDrops()

    property var rest: null          // the panel's length settings while the rail is grown
    property real panelLength: 0
    property int sentLength: 0
    function setPanelLength(len) {
        len = Math.round(len);
        if (len === sentLength) return;
        sentLength = len;
        panelScript('p.lengthMode = "custom"; p.minimumLength = ' + len + '; p.maximumLength = ' + len + ';');
    }
    onPanelLengthChanged: if (lengthAnim.running) setPanelLength(panelLength)
    NumberAnimation {
        id: lengthAnim
        target: root
        property: "panelLength"
        duration: Kirigami.Units.longDuration
        easing.type: Easing.OutCubic
        onFinished: {
            root.setPanelLength(root.panelLength);
            if (!root.shouldGrow && root.rest) root.putBack();
        }
    }
    readonly property bool shouldGrow: maximized && Plasmoid.configuration.fillWhenMaximized && !editMode
    function putBack() {
        const r = rest;
        rest = null;
        sentLength = 0;
        panelScript('p.lengthMode = "' + r.mode + '"; p.alignment = "' + r.alignment + '"; p.minimumLength = ' + r.min
                    + '; p.maximumLength = ' + r.max + ';');
    }
    function grow() {
        const reply = panelScript('print(JSON.stringify({ mode: p.lengthMode, alignment: p.alignment, min: p.minimumLength, '
                                  + 'max: p.maximumLength, len: p.length, floating: p.floating }));');
        reply.finished.connect(() => {
            if (reply.isError || !root.shouldGrow || root.rest) return;
            let st;
            try { st = JSON.parse(String(reply.value).trim()); } catch (e) { return; }
            // the visible length: the custom maximum, or the content for "fit"
            st.len = st.mode === "custom" ? Math.min(st.max, Screen.height) : st.len;
            if (st.floating || st.mode === "fill" || st.len >= Screen.height) return;
            root.rest = st;
            root.sentLength = st.len;
            panelScript('p.alignment = "center";');
            root.animateLength(st.len, Screen.height);
        });
    }
    function animateLength(from, to) {
        lengthAnim.stop();
        lengthAnim.from = from;
        lengthAnim.to = to;
        lengthAnim.start();
    }
    Timer {
        id: lengthTimer
        interval: 150 // let a maximize, restore or desktop switch settle first
        onTriggered: {
            if (root.shouldGrow && !root.rest) root.grow();
            else if (!root.shouldGrow && root.rest) {
                if (root.editMode) { lengthAnim.stop(); root.putBack(); } // show the real settings right away
                else root.animateLength(root.sentLength || Screen.height, root.rest.len);
            }
        }
    }
    onShouldGrowChanged: lengthTimer.restart()

    // ---- the rail lives on the left or right edge; a move to the top or bottom is sent back to its side
    property int side: PlasmaCore.Types.LeftEdge
    function keepSide() {
        const loc = Plasmoid.location;
        if (loc === PlasmaCore.Types.LeftEdge || loc === PlasmaCore.Types.RightEdge) side = loc;
        else if (loc === PlasmaCore.Types.TopEdge || loc === PlasmaCore.Types.BottomEdge)
            panelScript('p.location = "' + (side === PlasmaCore.Types.RightEdge ? "right" : "left") + '";');
    }
    Connections {
        target: Plasmoid
        function onLocationChanged() { Qt.callLater(root.keepSide) }
    }
    Component.onCompleted: {
        recountMaximized(); stackDesktops(); keepSide();
        Plasmoid.configuration.revealForMove = false; // left over if the shell stopped during a move
    }

    function currentIndex() {
        return vdi.desktopIds.indexOf(vdi.currentDesktop);
    }

    fullRepresentation: Item {
        id: rail
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: col.implicitHeight
        Layout.preferredHeight: col.implicitHeight

        readonly property real aspect: Screen.height > 0 ? Screen.height / Screen.width : 0.625
        readonly property real thumbW: Math.min(48, width - 14)
        readonly property real thumbH: Math.round(thumbW * aspect)

        // an open app box takes its pointer events up here: the app column is a ListView, which
        // keeps them from anything past its own edges
        readonly property Item stackLayer: stackLayerItem
        Item {
            id: stackLayerItem
            anchors.fill: parent
            z: 100
        }

        // ---- drags of apps and windows (see root.startDrag): the source, and where they land
        readonly property Item dragCard: dragCardItem
        DragCard {
            id: dragCardItem
            x: -10000 // out of view: only its image is shown, under the pointer
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.MoveAction
            Drag.mimeData: ({ [root.windowMime]: "rail" })
            Drag.hotSpot: Qt.point(pad + 24, pad + 22)
            Drag.onDragFinished: dropAction => root.finishDrag(dropAction)
        }
        DropArea {
            parent: stackLayerItem // above the app column and the boxes, which keep it from drops past its edges
            anchors.fill: parent
            z: 1
            keys: [root.windowMime]
            onEntered: drag => rail.dragMoved(drag.x, drag.y)
            onPositionChanged: drag => rail.dragMoved(drag.x, drag.y)
            onExited: { rail.dragDesktop = -1; root.setIncoming(null, -1); root.restoreOrder(root.dragSpec); }
            onDropped: drop => {
                rail.dragDropped(drop.x, drop.y);
                drop.accept(Qt.MoveAction);
                root.finishDrag(Qt.MoveAction); // done here, before any leave that follows
            }
        }
        // the app's tile, or the open box, under a point of the rail
        function taskAt(x, y) {
            const p = mapToItem(null, x, y);
            const open = root.stackTask;
            if (open && open.boxContains(p.x, p.y)) return open;
            const c = appCol.mapFromItem(rail, x, y);
            if (c.x < 0 || c.y < 0 || c.x >= appCol.width || c.y >= appCol.height) return null;
            const t = appCol.itemAt(c.x + appCol.contentX, c.y + appCol.contentY);
            return t && !t.covered && t.shown ? t : null;
        }
        function dragMoved(x, y) {
            const s = root.dragSpec;
            if (!s) return;
            const p = mapToItem(null, x, y);
            // a thumbnail: windows go there on drop, and a dwell goes there now; launchers have no windows
            const desk = s.winIds.length ? workspaceAt(p.x, p.y) : -1;
            dragDesktop = desk;
            if (desk >= 0) { root.setIncoming(null, -1); root.restoreOrder(s); return; }
            const t = taskAt(x, y);
            // the same app, other than the one dragged: it opens with a place for what comes
            if (t && s.winIds.length && t.launcher === s.launcher && (s.kind === "window" || !t.holdsDragged)) {
                root.setIncoming(t, t.slotAt(p.x, p.y));
                return;
            }
            root.setIncoming(null, -1);
            // an app over the others: live reorder
            if (s.kind === "app" && root.tasksModel.manual && t) {
                const row = root.dragRow(s);
                if (row >= 0 && t.index !== row) root.tasksModel.move(row, t.index);
            }
        }
        function dragDropped(x, y) {
            const s = root.dragSpec;
            if (!s) return;
            const p = mapToItem(null, x, y);
            const desk = s.winIds.length ? workspaceAt(p.x, p.y) : -1;
            if (desk >= 0) {
                root.restoreOrder(s);
                root.moveWindows(s.winIds, root.virtualDesktopInfo.desktopIds[desk], false);
                return;
            }
            const t = root.incomingTask;
            const slot = root.incomingSlot;
            // anywhere else on the rail brings the windows to this desktop
            if (root.dragSwitched(s) || t) root.moveWindows(s.winIds, root.virtualDesktopInfo.currentDesktop, true);
            if (t) root.placeWindows(s.winIds, s.launcher, slot);
        }

        // the workspace thumbnail an app tile is being dragged onto, -1 for none
        property int dragDesktop: -1

        // Which thumbnail is under a scene point, for app tiles dragged out of the app column.
        // Windows are handled by the KWin script below; their pointer never reaches the rail.
        function workspaceAt(sceneX, sceneY) {
            if (!wsCol.visible) return -1;
            for (let i = 0; i < wsRepeater.count; i++) {
                const t = wsRepeater.itemAt(i);
                if (!t) continue;
                const p = t.mapFromItem(null, sceneX, sceneY);
                if (p.x >= 0 && p.y >= 0 && p.x < t.width && p.y < t.height) return i;
            }
            return -1;
        }

        // ---- where the thumbnails are, in panel coordinates, for the KWin script that switches workspaces
        // under a moved window (kde/workspacedrag): KWin holds the pointer then, so no hover reaches us
        function publishZones() {
            const rects = [];
            for (let i = 0; wsCol.visible && i < wsRepeater.count; i++) {
                const t = wsRepeater.itemAt(i);
                if (!t) continue;
                const p = t.mapToItem(null, 0, 0);
                rects.push([Math.round(p.x), Math.round(p.y), Math.round(t.width), Math.round(t.height)]);
            }
            const zones = JSON.stringify({ width: rail.Window.width, rects: rects });
            if (Plasmoid.configuration.workspaceZones !== zones) Plasmoid.configuration.workspaceZones = zones;
        }
        Timer {
            id: zonesTimer
            interval: 500
            onTriggered: rail.publishZones()
        }
        onWidthChanged: zonesTimer.restart()
        onXChanged: zonesTimer.restart()
        onYChanged: zonesTimer.restart()
        Window.onWidthChanged: zonesTimer.restart()
        Window.onHeightChanged: zonesTimer.restart()
        Connections {
            target: root
            function onEditModeChanged() { zonesTimer.restart() }
        }
        Component.onCompleted: zonesTimer.restart()

        MouseArea {
            // wheel anywhere on the workspace block cycles desktops
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: col.top
            anchors.topMargin: wsCol.y
            height: wsCol.height
            visible: Plasmoid.configuration.showWorkspaces
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                const n = vdi.numberOfDesktops;
                const i = root.currentIndex() + (wheel.angleDelta.y < 0 ? 1 : -1);
                root.switchTo(((i % n) + n) % n + 1);
            }
        }

        GridLayout {
            id: col
            width: parent.width
            columns: 1
            rowSpacing: root.gap

            // ---- workspaces
            Column {
                id: wsCol
                Layout.fillWidth: true
                Layout.row: Plasmoid.configuration.workspacesFirst ? 0 : 3
                visible: Plasmoid.configuration.showWorkspaces
                spacing: root.gap + 2
                onVisibleChanged: zonesTimer.restart()
                onYChanged: zonesTimer.restart()
                onHeightChanged: zonesTimer.restart()
                Repeater {
                    id: wsRepeater
                    model: vdi.numberOfDesktops
                    delegate: Item {
                        id: ws
                        required property int index
                        readonly property var deskId: vdi.desktopIds[index]
                        readonly property bool current: index === root.currentIndex()
                        readonly property real s: width / Math.max(1, Screen.width)
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: rail.thumbW
                        height: rail.thumbH

                        Item {
                            id: face
                            anchors.fill: parent
                            opacity: ws.current || hover.hovered || dragHover.containsDrag || rail.dragDesktop === ws.index ? 1 : 0.72
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: faceMask
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1.0
                            }
                            Image {
                                anchors.fill: parent
                                source: Qt.resolvedUrl("../images/wall-" + (root.dark ? "dark" : "light") + ".jpg")
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            Repeater {
                                model: winModel
                                delegate: Rectangle {
                                    id: win
                                    required property var model
                                    readonly property var vds: model.VirtualDesktops || []
                                    readonly property var g: model.Geometry
                                    visible: model.IsWindow === true && !model.IsMinimized && !model.SkipPager
                                             && (model.IsOnAllVirtualDesktops === true || vds.indexOf(ws.deskId) >= 0)
                                    x: g ? Math.round(g.x * ws.s) : 0
                                    y: g ? Math.round(g.y * ws.s) : 0
                                    width: g ? Math.max(6, Math.round(g.width * ws.s)) : 0
                                    height: g ? Math.max(6, Math.round(g.height * ws.s)) : 0
                                    radius: 3
                                    // a translucent pane so the wallpaper still shows through, even when maximized
                                    color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g,
                                                   Kirigami.Theme.backgroundColor.b, 0.78)
                                    border.width: 1
                                    border.color: model.IsActive === true ? root.accent
                                                  : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.35)
                                    z: model.IsActive ? 2 : 1
                                    Rectangle { // title strip
                                        x: 1; y: 1
                                        width: parent.width - 2
                                        height: Math.min(3, (parent.height - 2) / 3)
                                        radius: 2
                                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
                                    }
                                    Kirigami.Icon { // which app it is
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: 1
                                        width: Math.min(16, Math.min(parent.width, parent.height) - 6)
                                        height: width
                                        visible: width >= 8
                                        source: win.model.decoration
                                    }
                                }
                            }
                            Rectangle { // desktop number
                                visible: Plasmoid.configuration.showWorkspaceNumbers
                                x: 3; y: parent.height - height - 3
                                z: 5
                                width: Math.max(11, num.implicitWidth + 5)
                                height: 11
                                radius: 3
                                color: Qt.rgba(0, 0, 0, 0.5)
                                Text {
                                    id: num
                                    anchors.centerIn: parent
                                    text: ws.index + 1
                                    color: "white"
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                }
                            }
                        }
                        Rectangle {
                            id: faceMask
                            anchors.fill: parent
                            radius: 7
                            visible: false
                            layer.enabled: true
                        }
                        Rectangle { // inner hairline
                            anchors.fill: parent
                            radius: 7
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.25)
                        }
                        Rectangle { // an app is dragged over: it will move here
                            anchors.fill: parent
                            anchors.margins: -2
                            radius: 9
                            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                            border.width: 2
                            border.color: root.accent
                            visible: rail.dragDesktop === ws.index
                        }
                        Rectangle { // current: accent ring with a pale halo
                            anchors.fill: parent
                            anchors.margins: -2
                            radius: 9
                            color: "transparent"
                            border.width: 2
                            border.color: root.accent
                            visible: ws.current
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -1.5
                                radius: parent.radius + 1.5
                                color: "transparent"
                                border.width: 1.5
                                border.color: Qt.rgba(1, 1, 1, 0.4)
                            }
                        }
                        HoverHandler { id: hover }
                        TapHandler { onTapped: root.switchTo(ws.index + 1) }
                        MouseArea { // accepts the click, so Plasma's own panel menu stays closed
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            onClicked: root.openWorkspaceMenu(ws)
                        }
                        // hovering with a file, an app tile or anything else held switches without ending the drag
                        DropArea { // apps and windows are taken by the rail's own drop area, see dragMoved
                            id: dragHover
                            anchors.fill: parent
                            enabled: !root.editMode
                        }
                        Timer {
                            interval: 350
                            running: (dragHover.containsDrag || rail.dragDesktop === ws.index) && !ws.current
                            onTriggered: root.switchTo(ws.index + 1)
                        }
                    }
                }
                Item { // add a workspace
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: rail.thumbW
                    height: 22
                    visible: Plasmoid.configuration.showAddWorkspace && vdi.numberOfDesktops < Plasmoid.configuration.maxDesktops
                    Rectangle {
                        anchors.fill: parent
                        radius: 7
                        color: addHover.hovered ? root.fillHover : root.fill
                        border.width: 1
                        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.3)
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 14; height: 14
                        source: "list-add-symbolic"
                        color: Kirigami.Theme.textColor
                        opacity: 0.7
                    }
                    HoverHandler { id: addHover }
                    TapHandler { onTapped: root.addDesktop() }
                }
            }

            Item { // separator with air on both sides
                Layout.fillWidth: true
                Layout.preferredHeight: 15
                Layout.row: Plasmoid.configuration.workspacesFirst ? 1 : 2
                visible: Plasmoid.configuration.showSeparator && Plasmoid.configuration.showWorkspaces && Plasmoid.configuration.showApps
                Rectangle {
                    anchors.centerIn: parent
                    width: 28; height: 1
                    color: Kirigami.Theme.textColor
                    opacity: 0.18
                }
            }

            // ---- apps
            ListView {
                id: appCol
                Layout.fillWidth: true
                Layout.preferredHeight: contentHeight
                Layout.row: Plasmoid.configuration.workspacesFirst ? 2 : 0
                visible: Plasmoid.configuration.showApps
                interactive: false
                spacing: Plasmoid.configuration.appSpacing
                // New tasks appear at the bottom, or at the top
                verticalLayoutDirection: Plasmoid.configuration.reverseMode ? ListView.BottomToTop : ListView.TopToBottom
                model: appModel
                delegate: Task { r: root; view: appCol }
                displaced: Transition { NumberAnimation { properties: "y"; duration: 140; easing.type: Easing.OutCubic } }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    enabled: Plasmoid.configuration.wheelEnabled !== 0
                    property real acc: 0
                    onWheel: event => {
                        acc += event.angleDelta.y;
                        const steps = Math.trunc(acc / 120);
                        if (!steps) return;
                        acc -= steps * 120;
                        root.wheelTasks(appCol.itemAt(event.x, event.y + appCol.contentY), steps);
                    }
                }
                // apps dropped on the column are pinned
                DropArea {
                    anchors.fill: parent
                    z: -1
                    keys: ["text/uri-list"]
                    onDropped: drop => {
                        if (drop.hasUrls && drop.urls.every(u => root.isApplication(u))) {
                            drop.urls.forEach(u => appModel.requestAddLauncher(u));
                            drop.accept(Qt.CopyAction);
                        }
                    }
                }
            }
        }
    }
}
