/*
    One app on the rail. Click, middle-click, wheel and drop behaviour follow KDE's task manager
    (plasma-desktop applets/taskmanager/qml/Task.qml, code/TaskTools.js).
*/
import QtQuick
import QtQml.Models
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

Item {
    id: task

    required property int index
    required property var model
    required property var r          // the rail root
    required property ListView view

    readonly property bool isWindow: model.IsWindow === true
    readonly property bool isGroup: model.IsGroupParent === true
    readonly property bool isLauncher: model.IsLauncher === true
    readonly property bool isStartup: model.IsStartup === true
    readonly property bool running: isWindow || isGroup
    readonly property bool active: model.IsActive === true
    readonly property int windows: isGroup ? (model.ChildCount || 0) : (running ? 1 : 0)
    readonly property bool shown: Plasmoid.configuration.showPinned || !isLauncher

    // audio, as in KDE: streams matched by sandbox app id, pid, then app name
    property var audioStreams: []
    readonly property bool hasAudioStream: audioStreams.length > 0
    readonly property bool playingAudio: hasAudioStream && audioStreams.some(s => !s.corked)
    readonly property bool muted: hasAudioStream && audioStreams.every(s => s.muted)
    function updateAudioStreams() {
        const pa = r.pulseAudio;
        if (!pa || !running) { audioStreams = []; return; }
        audioStreams = pa.streamsFor(model.AppId ? model.AppId.replace(/\.desktop$/, "") : "", model.AppPid || 0, model.AppName || "");
    }
    function toggleMuted() {
        const m = !muted;
        for (const s of audioStreams) s.setMuted(m);
    }
    Connections {
        target: task.r.pulseAudio
        function onStreamsChanged() { task.updateAudioStreams() }
    }

    width: ListView.view ? ListView.view.width : 0
    height: shown ? r.tile : 0
    visible: shown
    z: reveal > 0 ? 5 : 0
    readonly property string launcher: String(model.LauncherUrlWithoutIcon || "")

    // ---- dragged: the app itself, or one of its windows (see root.beginDrag)
    property bool holdsDragged: false  // holds a dragged window, or is the dragged launcher
    property int draggedRow: -1        // the entry of a dragged window
    function updateDragged() {
        const s = r.dragSpec;
        draggedRow = -1;
        if (!s) { holdsDragged = false; return; }
        if (!s.winIds.length) { holdsDragged = isLauncher && launcher === s.launcher; return; }
        const kids = isGroup ? [...Array(r.tasksModel.rowCount(modelIndex())).keys()].map(c => r.tasksModel.makeModelIndex(index, c)) : [modelIndex()];
        const k = kids.findIndex(i => (r.tasksModel.data(i, TaskManager.AbstractTasksModel.WinIdList) || []).some(id => s.winIds.indexOf(String(id)) >= 0));
        holdsDragged = k >= 0;
        if (k >= 0 && s.kind === "window" && isGroup) draggedRow = k;
    }
    Connections {
        target: task.r
        function onDragSpecChanged() { task.updateDragged() }
    }
    // a reorder resorts the model, which can hand this tile another task without an index change
    readonly property var winIdList: model.WinIdList
    onIndexChanged: if (r.dragSpec) updateDragged()
    onWindowsChanged: if (r.dragSpec) updateDragged()
    onWinIdListChanged: if (r.dragSpec) updateDragged()
    onLauncherChanged: if (r.dragSpec) updateDragged()
    onIsLauncherChanged: if (r.dragSpec) updateDragged()
    // the dragged app keeps its place in the column, faint
    readonly property bool dragged: r.dragSpec !== null && r.dragSpec.kind === "app" && holdsDragged

    // ---- grouped apps: on hover the tile grows into a box with one entry per window, over the
    // apps next to it. A dragged window or app of the same kind opens it too, with a slot for it.
    readonly property bool receiving: r.incomingTask === task
    readonly property int incomingSlot: receiving ? r.incomingSlot : -1
    readonly property bool canExpand: isGroup && windows > 1
    property int holds: 0              // entries that keep the box open: hovered, previewed or in a menu
    readonly property bool wantExpand: (canExpand || receiving) && !r.editMode
        && (receiving || (r.dragSpec !== null && r.dragSpec.kind === "window" && holdsDragged)
            || (r.dragSpec === null && ((!r.menuOpen && (hover.hovered || boxHover.hovered)) || holds > 0)))
    property bool expanded: false
    property bool growUp: false
    property int focusedRow: -1        // where the focused window's entry is, set by the entries
    // entries are tiles like the apps, with the column's spacing between them
    property real entryH: r.tile
    readonly property int entryGap: Math.max(6, Plasmoid.configuration.appSpacing)
    readonly property real entryStep: entryH + entryGap
    readonly property int boxPad: 0      // the last entry's hover fills to the box's edge, as the app's does at the other
    readonly property int shownEntries: windows - (draggedRow >= 0 ? 1 : 0)
    readonly property int slots: shownEntries + (incomingSlot >= 0 ? 1 : 0)
    readonly property real extra: expanded ? slots * entryStep + boxPad : 0
    // where an entry, or the incoming slot, sits in the box
    function slotY(pos) { return (growUp ? 0 : entryGap) + pos * entryStep; }
    // the slot a scene point picks; over the app's own tile, the end
    function slotAt(sx, sy) {
        const p = box.mapFromItem(null, sx, sy);
        if (!expanded || p.y < 0 || p.y >= box.height) return shownEntries;
        return Math.max(0, Math.min(shownEntries, Math.floor((p.y - (growUp ? 0 : entryGap / 2)) / entryStep)));
    }
    function boxContains(sx, sy) {
        const b = box.mapFromItem(null, sx, sy);
        const t = task.mapFromItem(null, sx, sy);
        return (box.visible && b.x >= 0 && b.y >= 0 && b.x < box.width && b.y < box.height)
            || (t.x >= 0 && t.y >= 0 && t.x < task.width && t.y < task.height);
    }
    // where the box sits in the rail's stack layer: the tile's top left
    property point boxOrigin: Qt.point(0, 0)
    function placeBox() {
        const layer = r.fullRepresentationItem ? r.fullRepresentationItem.stackLayer : null;
        if (layer) boxOrigin = task.mapToItem(layer, 0, 0);
    }
    property real reveal: extra
    // 0..1: how far the tile has become the canvas surface, focused or open; and how far it floats
    property real lift: active || expanded ? 1 : 0
    Behavior on lift { NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
    property real openness: expanded ? 1 : 0
    Behavior on openness { NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
    Behavior on reveal { NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
    onWantExpandChanged: {
        if (wantExpand) { collapseTimer.stop(); if (!expanded) openTimer.restart(); }
        else { openTimer.stop(); if (expanded) collapseTimer.restart(); }
    }
    Timer { id: openTimer; interval: 150; onTriggered: task.expand() }
    Timer { id: collapseTimer; interval: 300; onTriggered: task.expanded = false }
    onExpandedChanged: {
        if (expanded) r.stackTask = task;
        else if (r.stackTask === task) r.stackTask = null;
    }
    // grows down when the rail has room below, else up; shrinks the entries when it has neither
    function expand() {
        const rail = r.fullRepresentationItem;
        const n = Math.max(1, slots);
        let h = r.tile;
        const p = rail ? task.mapToItem(rail, 0, 0) : Qt.point(0, 0);
        const below = rail ? rail.height - p.y - r.tile : Infinity;
        const above = p.y;
        const need = n * (h + entryGap) + boxPad;
        growUp = below < need && above > below;
        const room = growUp ? above : below;
        if (need > room) h = Math.max(20, Math.floor((room - boxPad) / n) - entryGap);
        entryH = h;
        placeBox();
        expanded = true;
        // opened by hover: the focused window's preview comes with it, on the same delay
        if (!receiving && hover.hovered) { updatePreview(); Qt.callLater(showToolTip); }
    }
    // the window the app's own tile previews while its box is open: the focused one, else the one used last
    property int previewRow: -1
    property var previewData: null
    function updatePreview() {
        const tm = r.tasksModel;
        const R = TaskManager.AbstractTasksModel;
        const kids = [...Array(tm.rowCount(modelIndex())).keys()].map(c => tm.makeModelIndex(index, c));
        if (!kids.length) { previewRow = -1; previewData = null; return; }
        let k = kids.findIndex(i => tm.data(i, R.IsActive) === true);
        if (k < 0) {
            const top = r.groupTopTask(kids, R.LastActivated);
            k = top !== undefined ? top.row : 0;
        }
        const i = kids[k];
        previewData = { decoration: tm.data(i, Qt.DecorationRole), display: tm.data(i, Qt.DisplayRole),
                        WinIdList: tm.data(i, R.WinIdList), IsActive: tm.data(i, R.IsActive), IsMinimized: tm.data(i, R.IsMinimized) };
        previewRow = k;
    }
    // the window entry under a scene point, for the rail's drag handler
    function entryAt(sx, sy) {
        for (const rep of [groupEntries, singleEntries]) {
            for (let i = 0; i < rep.count; ++i) {
                const e = rep.itemAt(i);
                if (!e || !e.visible) continue;
                const p = e.mapFromItem(null, sx, sy);
                if (p.x >= 0 && p.y >= 0 && p.x < e.width && p.y < e.height) return e;
            }
        }
        return null;
    }
    function entryIcons() {
        const tm = r.tasksModel;
        return [...Array(tm.rowCount(modelIndex())).keys()].map(c => tm.data(tm.makeModelIndex(index, c), Qt.DecorationRole));
    }
    // an open box of another app covers this one
    readonly property bool covered: r.stackTask !== null && r.stackTask !== task
                                    && y < r.stackBottom && y + height > r.stackTop
    enabled: !covered

    function modelIndex() { return r.tasksModel.makeModelIndex(index); }
    function showToolTip() { tipArea.showToolTip(); }
    function hideToolTip() { tipArea.hideImmediately(); }

    // Where windows minimize to: KWin animates them into this tile
    function publishGeometry() {
        if (!running || !Window.window) return;
        const g = task.mapToGlobal(0, 0);
        r.tasksModel.requestPublishDelegateGeometry(modelIndex(), Qt.rect(g.x, g.y, width, height), task);
    }
    Timer { id: publishTimer; interval: 200; onTriggered: task.publishGeometry() }
    onYChanged: { publishTimer.restart(); if (reveal > 0) placeBox(); }
    onRunningChanged: { updateAudioStreams(); publishTimer.restart(); }
    Component.onCompleted: { publishTimer.restart(); updateAudioStreams(); if (r.dragSpec) updateDragged(); }

    // ---- click: KDE's activateTask
    function activate(modifiers) {
        const tm = r.tasksModel;
        const idx = modelIndex();
        if ((modifiers & Qt.ShiftModifier) || isLauncher) { tm.requestNewInstance(idx); return; }
        if (isStartup) return;
        if (isGroup) {
            // the expanded box already shows the windows, so "small window previews" cycles instead
            const mode = Plasmoid.configuration.groupedTaskVisualization;
            switch (mode === 1 && canExpand ? 0 : mode) {
            case 1: // small window previews
                if (r.toolTipOpenedByClick === task) { hideToolTip(); r.toolTipOpenedByClick = null; }
                else { r.toolTipOpenedByClick = task; showToolTip(); }
                return;
            case 2: // large previews, side by side (Window View); falls back to the list
                if (r.windowViewAvailable) { hideToolTip(); r.activateWindowView(model.WinIdList); return; }
                r.openGroupList(task);
                return;
            case 3: // textual list
                r.openGroupList(task);
                return;
            default: { // cycle: the group's last used window first, then the next one on each click
                const kids = [];
                for (let i = 0; i < tm.rowCount(idx); ++i) kids.push(tm.makeModelIndex(index, i));
                const cur = kids.findIndex(k => tm.data(k, TaskManager.AbstractTasksModel.IsActive));
                if (cur >= 0) { tm.requestActivate(kids[(cur + 1) % kids.length]); return; }
                let top = r.groupTopTask(kids, TaskManager.AbstractTasksModel.LastActivated);
                if (top === undefined) top = r.groupTopTask(kids, TaskManager.AbstractTasksModel.StackingOrder);
                tm.requestActivate(top !== undefined ? top : kids[0]);
                return;
            }
            }
        }
        if (model.IsMinimized === true) { tm.requestToggleMinimized(idx); tm.requestActivate(idx); }
        else if (active && Plasmoid.configuration.minimizeActiveTaskOnClick) tm.requestToggleMinimized(idx);
        else tm.requestActivate(idx);
    }

    function middleClick() {
        const tm = r.tasksModel;
        const idx = modelIndex();
        switch (Plasmoid.configuration.middleClickAction) {
        case 1: if (running) tm.requestClose(idx); break;
        case 2: tm.requestNewInstance(idx); break;
        case 3: if (running) tm.requestToggleMinimized(idx); break;
        case 4: if (running) tm.requestToggleGrouping(idx); break;
        case 5: if (running) r.foreachChildTask(i => tm.requestVirtualDesktops(i, [r.virtualDesktopInfo.currentDesktop]), idx); break;
        }
    }

    // ---- drag: onto another place in the column, a workspace thumbnail or the same app elsewhere
    readonly property bool canReorder: r.tasksModel.sortMode === TaskManager.TasksModel.SortManual
    readonly property bool canDrag: canReorder || running
    function winIdsAt(idx) {
        const ids = [];
        r.foreachChildTask(i => {
            const list = r.tasksModel.data(i, TaskManager.AbstractTasksModel.WinIdList) || [];
            for (const id of list) ids.push(String(id));
        }, idx);
        return ids;
    }

    Item {
        id: body
        width: parent.width; height: parent.height
        opacity: task.covered ? 0 : task.dragged ? 0.35 : 1
        Behavior on opacity { NumberAnimation { duration: 120 } }

        // Running marks on the screen edge: one per window, up to four; the focused app's are longer.
        // While the box is open they gather into one beside the focused window's entry.
        Item {
            id: marks
            x: 0
            width: 3.5
            height: parent.height
            visible: task.running && Plasmoid.configuration.showRunningIndicator
            readonly property int n: Math.min(4, Math.max(1, task.windows))
            readonly property real len: n === 1 ? (task.active ? 28 : 14) : (task.active ? 8 : 5)
            readonly property int gap: 3
            readonly property real total: n * len + (n - 1) * gap
            readonly property bool merged: task.expanded && task.focusedRow >= 0
            readonly property real mergedLen: Math.min(28, task.entryH - 8)
            readonly property real mergedCenter: (task.growUp ? -task.extra : task.r.tile) + task.slotY(task.focusedRow) + task.entryH / 2
            Repeater {
                model: marks.n
                Rectangle {
                    required property int index
                    width: 3.5
                    y: marks.merged ? marks.mergedCenter - marks.mergedLen / 2
                                    : (marks.height - marks.total) / 2 + index * (marks.len + marks.gap)
                    height: marks.merged ? marks.mergedLen : marks.len
                    radius: 2
                    color: task.r.accent
                    opacity: !marks.merged && task.model.IsMinimized === true ? 0.5 : 1
                    // emphasized: they travel together and settle
                    Behavior on y { NumberAnimation { duration: 380; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] } }
                    Behavior on height { NumberAnimation { duration: 380; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    Rectangle { width: 2; height: parent.height; color: parent.color } // flat on the screen edge
                }
            }
        }
        Kirigami.ShadowedRectangle { // resting tile: shows behind icons that are not full-bleed, and grows into the box
            anchors.horizontalCenter: parent.horizontalCenter
            width: task.r.tile
            y: task.growUp ? -task.reveal : 0
            height: task.r.tile + task.reveal
            radius: task.r.tile * 0.26
            // focused or open it is the canvas surface; open, it floats over the apps beside it with a soft shadow
            color: Qt.tint(task.r.fill, Qt.rgba(task.r.tileLifted.r, task.r.tileLifted.g, task.r.tileLifted.b, task.lift))
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, task.r.dark ? 0.12 : 0.6)
            shadow.size: 16 * task.openness
            shadow.yOffset: 3
            shadow.color: Qt.rgba(0, 0, 0, (task.r.dark ? 0.4 : 0.2) * task.openness)
        }
        Item { // the windows, revealed as the box grows; up in the rail's stack layer, see stackLayer
            id: box
            parent: task.r.fullRepresentationItem ? task.r.fullRepresentationItem.stackLayer : body
            x: task.boxOrigin.x + (task.width - task.r.tile) / 2
            y: task.boxOrigin.y + (task.growUp ? -task.reveal : task.r.tile)
            width: task.r.tile
            height: task.reveal
            clip: true
            visible: task.reveal > 0 && task.visible
            HoverHandler { id: boxHover; blocking: true }
            MouseArea { // clicks between the entries stay in the box
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }
            Rectangle { // sets the windows apart from the app
                x: 8; width: parent.width - 16
                height: 1
                y: task.growUp ? parent.height - Math.ceil(task.entryGap / 2) - 1 : Math.floor(task.entryGap / 2)
                color: Kirigami.Theme.textColor
                opacity: 0.14
            }
            Item { // entries sit at their slots, making room where a dragged window would go
                anchors.fill: parent
                opacity: task.expanded ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                Repeater {
                    id: groupEntries
                    model: DelegateModel {
                        model: task.isGroup && (task.expanded || task.reveal > 0) ? task.r.tasksModel : null
                        rootIndex: task.isGroup ? task.r.tasksModel.makeModelIndex(task.index) : null
                        delegate: WindowEntry { owner: task }
                    }
                }
                Repeater { // an app with one window, opened for a window of its kind
                    id: singleEntries
                    model: !task.isGroup && task.running && (task.expanded || task.reveal > 0) ? 1 : 0
                    delegate: WindowEntry { owner: task; single: true }
                }
                Item { // where the dragged window goes: its icon, faint
                    visible: task.incomingSlot >= 0
                    width: parent.width
                    height: task.entryH
                    y: task.slotY(Math.max(0, task.incomingSlot))
                    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
                    Rectangle {
                        anchors.fill: parent
                        radius: task.r.tile * 0.26
                        color: task.r.tileHover
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Math.min(Plasmoid.configuration.iconSize, task.entryH - 8); height: width
                        roundToIconSize: false
                        source: task.r.dragSpec ? task.r.dragSpec.icon : ""
                        opacity: 0.45
                    }
                }
            }
        }
        Kirigami.Icon {
            id: icon
            anchors.centerIn: parent
            width: Plasmoid.configuration.iconSize; height: width
            roundToIconSize: false
            source: task.model.decoration
            SequentialAnimation on opacity { // launching
                running: task.isStartup
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.4; duration: 500; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutQuad }
            }
        }
        Rectangle { // hover and press recolor the whole tile, icon included
            anchors.horizontalCenter: parent.horizontalCenter
            width: task.r.tile; height: task.r.tile
            radius: task.r.tile * 0.26
            color: tap.pressed ? task.r.tilePressed : hover.hovered ? task.r.tileHover : Qt.rgba(0, 0, 0, 0)
            Behavior on color { ColorAnimation { duration: task.r.tileHoverDuration } }
        }
        Rectangle { // asks for attention
            id: attention
            anchors.horizontalCenter: parent.horizontalCenter
            width: task.r.tile; height: task.r.tile
            radius: task.r.tile * 0.26
            color: task.r.accent
            opacity: 0
            visible: Plasmoid.configuration.highlightAttention && task.model.IsDemandingAttention === true
            SequentialAnimation on opacity {
                running: attention.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.5; duration: 600 }
                NumberAnimation { to: 0.1; duration: 600 }
            }
        }
        Rectangle { // plays audio: a speaker badge on the tile corner; click mutes
            id: audioBadge
            visible: Plasmoid.configuration.indicateAudioStreams && task.hasAudioStream && (task.playingAudio || task.muted)
            x: parent.width / 2 + task.r.tile / 2 - width + 3
            y: parent.height / 2 - task.r.tile / 2 - 3
            width: 18; height: 18; radius: 9
            color: Kirigami.Theme.backgroundColor
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
            z: 2
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 12; height: 12
                source: task.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                color: Kirigami.Theme.textColor
                isMask: true
            }
            TapHandler {
                id: muteTap
                enabled: Plasmoid.configuration.interactiveMute
                onTapped: task.toggleMuted()
            }
        }
    }

    PlasmaCore.ToolTipArea {
        id: tipArea
        anchors.fill: parent
        // an app with a box previews its focused window, once the box is open
        active: !task.r.dragSpec && !task.r.menuOpen
                && (task.canExpand ? task.expanded : (Plasmoid.configuration.showToolTips || task.isLauncher || !task.isGroup))
        location: Plasmoid.location
        interactive: Plasmoid.configuration.showToolTips && !task.isLauncher
        mainItem: TaskToolTip {
            r: task.r
            task: task
            child: task.canExpand ? task.previewRow : -1
            childModel: task.canExpand ? task.previewData : null
            active: tipArea.containsMouse || task.r.toolTipOpenedByClick === task
        }
        onContainsMouseChanged: if (!containsMouse && task.r.toolTipOpenedByClick === task) task.r.toolTipOpenedByClick = null
    }

    HoverHandler {
        id: hover
        // back on the tile of an open box: its preview at once, the box's delay already passed
        onHoveredChanged: if (hovered && task.expanded && task.canExpand && !task.r.dragSpec) { task.updatePreview(); task.showToolTip(); }
    }
    // dragging is done by the rail's own handler (main.qml, dragLayer), which outlives this tile
    MouseArea { // accepts the click, so Plasma's own panel menu stays closed
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: { task.hideToolTip(); task.r.openTaskMenu(task); }
    }
    TapHandler {
        id: tap
        acceptedButtons: Qt.LeftButton
        onTapped: (point, button) => {
            // the tile's handler sees the badge's tap too; muting must not activate
            if (audioBadge.visible && muteTap.enabled && audioBadge.contains(audioBadge.mapFromItem(task, point.position))) return;
            task.activate(point.modifiers);
        }
    }
    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: task.middleClick()
    }

    // ---- files dragged over: hovering raises the window, dropping opens them with the app
    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onEntered: drag => { if (!task.isLauncher) raiseTimer.restart(); }
        onExited: raiseTimer.stop()
        onDropped: drop => {
            raiseTimer.stop();
            if (!drop.hasUrls) return;
            if (drop.urls.every(u => task.r.isApplication(u))) { drop.urls.forEach(u => task.r.tasksModel.requestAddLauncher(u)); return; }
            task.r.tasksModel.requestOpenUrls(task.modelIndex(), drop.urls);
            drop.accept(Qt.CopyAction);
        }
        Timer {
            id: raiseTimer
            interval: 250
            onTriggered: task.isGroup ? task.r.openGroupList(task) : task.r.tasksModel.requestActivate(task.modelIndex())
        }
    }

    Component.onDestruction: {
        if (task.r.stackTask === task) task.r.stackTask = null;
        if (task.r.incomingTask === task) task.r.setIncoming(null, -1);
    }
}
