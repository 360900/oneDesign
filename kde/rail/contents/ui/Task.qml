/*
    One app on the rail. Click, middle-click, wheel and drop behaviour follow KDE's task manager
    (plasma-desktop applets/taskmanager/qml/Task.qml, code/TaskTools.js).
*/
import QtQuick
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
    z: dragH.active ? 10 : 0

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
    onYChanged: publishTimer.restart()
    onRunningChanged: { updateAudioStreams(); publishTimer.restart(); }
    Component.onCompleted: { publishTimer.restart(); updateAudioStreams(); }

    // ---- click: KDE's activateTask
    function activate(modifiers) {
        const tm = r.tasksModel;
        const idx = modelIndex();
        if ((modifiers & Qt.ShiftModifier) || isLauncher) { tm.requestNewInstance(idx); return; }
        if (isStartup) return;
        if (isGroup) {
            switch (Plasmoid.configuration.groupedTaskVisualization) {
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

    // ---- drag to reorder
    property int startIndex: 0
    readonly property real step: r.tile + view.spacing
    readonly property real dy: dragH.active ? dragH.centroid.scenePosition.y - dragH.centroid.scenePressPosition.y : 0
    readonly property int dir: view.verticalLayoutDirection === ListView.BottomToTop ? -1 : 1
    onDyChanged: if (dragH.active) {
        const t = Math.max(0, Math.min(r.tasksModel.count - 1, Math.round(startIndex + dir * dy / step)));
        if (t !== index) r.tasksModel.move(index, t);
    }

    Item {
        id: body
        width: parent.width; height: parent.height
        y: dragH.active ? task.dy - task.dir * (task.index - task.startIndex) * task.step : 0
        opacity: dragH.active ? 0.85 : 1
        Behavior on y { enabled: !dragH.active; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        // Running marks on the screen edge: one per window, up to four; the focused app's are longer
        Column {
            id: marks
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            visible: task.running && Plasmoid.configuration.showRunningIndicator
            readonly property int n: Math.min(4, Math.max(1, task.windows))
            readonly property real len: n === 1 ? (task.active ? 28 : 14) : (task.active ? 8 : 5)
            Repeater {
                model: marks.n
                Rectangle {
                    width: 3.5
                    height: marks.len
                    radius: 2
                    color: task.r.accent
                    opacity: task.model.IsMinimized === true ? 0.5 : 1
                    Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Rectangle { width: 2; height: parent.height; color: parent.color } // flat on the screen edge
                }
            }
        }
        Rectangle { // resting tile: shows behind icons that are not full-bleed
            anchors.horizontalCenter: parent.horizontalCenter
            width: task.r.tile; height: task.r.tile
            radius: task.r.tile * 0.26
            color: task.r.fill
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, task.r.dark ? 0.12 : 0.6)
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
            color: tap.pressed ? Qt.rgba(task.r.accent.r, task.r.accent.g, task.r.accent.b, 0.25)
                   : hover.hovered ? (task.r.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.10))
                   : task.active ? (task.r.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)) : Qt.rgba(0, 0, 0, 0)
            Behavior on color { ColorAnimation { duration: 100 } }
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
        active: !dragH.active && !task.r.menuOpen && (Plasmoid.configuration.showToolTips || task.isLauncher || !task.isGroup)
        location: Plasmoid.location
        interactive: Plasmoid.configuration.showToolTips && !task.isLauncher
        mainItem: TaskToolTip {
            r: task.r
            task: task
            active: tipArea.containsMouse || task.r.toolTipOpenedByClick === task
        }
        onContainsMouseChanged: if (!containsMouse && task.r.toolTipOpenedByClick === task) task.r.toolTipOpenedByClick = null
    }

    HoverHandler { id: hover }
    DragHandler {
        id: dragH
        enabled: r.tasksModel.sortMode === TaskManager.TasksModel.SortManual
        target: null
        acceptedButtons: Qt.LeftButton
        xAxis.enabled: false
        onActiveChanged: {
            if (active) { task.startIndex = task.index; task.hideToolTip(); }
            else r.tasksModel.syncLaunchers(); // move() alone does not touch the launcher list
        }
    }
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
}
