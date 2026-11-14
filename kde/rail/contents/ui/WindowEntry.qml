/*
    One window of an app, in the app's expanded box. Hover shows its preview, click focuses it,
    right-click opens its menu, middle-click closes it. Drag it within the box to reorder, onto a
    workspace thumbnail to move just this window there, or onto the same app on another workspace.
*/
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

Item {
    id: entry

    required property int index
    required property var model
    required property Item owner   // the app's tile
    property bool single: false    // the app's only window: the tile's own task, not a group child
    readonly property var r: owner.r
    readonly property var win: single ? owner.model : model
    readonly property var winId: (win.WinIdList || [])[0]
    readonly property var idx: single ? owner.modelIndex() : r.tasksModel.makeModelIndex(owner.index, index)
    function modelIndex() { return idx; } // for the task menu
    readonly property bool active: win.IsActive === true

    // where it sits in the box: past a dragged window of the group, and making room for an incoming one
    readonly property bool dragged: index === owner.draggedRow
    readonly property int pos: {
        let p = index - (owner.draggedRow >= 0 && index > owner.draggedRow ? 1 : 0);
        return owner.incomingSlot >= 0 && p >= owner.incomingSlot ? p + 1 : p;
    }
    visible: !dragged
    y: owner.slotY(pos)
    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

    // the app's edge marks gather beside the focused window's entry
    property bool focusShown: false
    readonly property bool showsFocus: active && !dragged
    onShowsFocusChanged: showFocus()
    onPosChanged: showFocus()
    Component.onCompleted: showFocus()
    function showFocus() {
        if (showsFocus) { owner.focusedRow = pos; focusShown = true; }
        else if (focusShown) { if (owner.focusedRow === pos) owner.focusedRow = -1; focusShown = false; }
    }

    property bool menuShown: false
    Connections {
        target: entry.r
        function onMenuOpenChanged() { if (!entry.r.menuOpen) entry.menuShown = false; }
    }
    // keeps the box open while the pointer is here, on this window's preview or in its menu
    readonly property bool busy: hover.hovered || tip.hovered || menuShown
    property bool counted: false
    onBusyChanged: hold(busy)
    function hold(on) {
        if (on === counted) return;
        counted = on;
        owner.holds += on ? 1 : -1;
    }
    Component.onDestruction: {
        hold(false);
        if (focusShown && owner.focusedRow === pos) owner.focusedRow = -1;
    }

    width: r.tile
    height: owner.entryH

    function activate() {
        const tm = r.tasksModel;
        r.cancelHighlightWindows();
        if (win.IsMinimized === true) { tm.requestToggleMinimized(idx); tm.requestActivate(idx); }
        else if (active && Plasmoid.configuration.minimizeActiveTaskOnClick) tm.requestToggleMinimized(idx);
        else tm.requestActivate(idx);
    }

    Rectangle { // hover and press, the whole tile like the app's: the last one meets the box's corners
        anchors.fill: parent
        radius: entry.r.tile * 0.26
        color: tap.pressed ? entry.r.tilePressed : hover.hovered ? entry.r.tileHover : Qt.rgba(0, 0, 0, 0)
        Behavior on color { ColorAnimation { duration: entry.r.tileHoverDuration } }
    }
    Kirigami.Icon {
        anchors.centerIn: parent
        width: Math.min(Plasmoid.configuration.iconSize, entry.height - 8)
        height: width
        roundToIconSize: false
        source: entry.win.decoration
        opacity: entry.win.IsMinimized === true ? 0.5 : 1
    }

    PlasmaCore.ToolTipArea {
        id: tipArea
        anchors.fill: parent
        active: !entry.r.dragSpec && !entry.r.menuOpen
        location: Plasmoid.location
        interactive: true
        mainItem: TaskToolTip {
            id: tip
            r: entry.r
            task: entry.owner
            child: entry.index
            childModel: entry.win
            hideFn: () => tipArea.hideImmediately()
            active: tipArea.containsMouse
        }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            entry.r.windowsHovered(entry.win.WinIdList, hovered);
        }
    }
    TapHandler {
        id: tap
        acceptedButtons: Qt.LeftButton
        onTapped: entry.activate()
    }
    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: entry.r.tasksModel.requestClose(entry.idx)
    }
    MouseArea { // this window's menu; accepting the click keeps Plasma's own panel menu closed
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: {
            tipArea.hideImmediately();
            entry.menuShown = true;
            entry.r.openTaskMenu(entry);
        }
    }

    DragHandler {
        id: dragH
        target: null
        enabled: entry.winId !== undefined
        onActiveChanged: if (active) {
            tipArea.hideImmediately();
            entry.r.startDrag({ kind: "window", winIds: [String(entry.winId)], launcher: entry.owner.launcher },
                              entry.win.decoration, entry.win.display, () => dragH.active);
        }
    }
}
