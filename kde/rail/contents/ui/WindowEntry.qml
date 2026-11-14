/*
    One window of a grouped app, in the app's expanded box. Hover shows its preview, click focuses
    it, middle-click closes it, and dragging it onto a workspace thumbnail moves just this window.
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
    readonly property var r: owner.r
    readonly property var winId: (model.WinIdList || [])[0]
    readonly property var modelIndex: r.tasksModel.makeModelIndex(owner.index, index)
    readonly property bool active: model.IsActive === true

    property bool dragging: false
    // keeps the box open while the pointer is here, on this window's preview, or dragging it
    readonly property bool busy: hover.hovered || tip.hovered || dragging
    property bool counted: false
    onBusyChanged: hold(busy)
    function hold(on) {
        if (on === counted) return;
        counted = on;
        owner.holds += on ? 1 : -1;
    }
    Component.onDestruction: {
        hold(false);
        if (dragging) r.endWindowDrag([], false);
    }

    width: r.tile
    height: owner.entryH

    function activate() {
        const tm = r.tasksModel;
        r.cancelHighlightWindows();
        if (model.IsMinimized === true) { tm.requestToggleMinimized(modelIndex); tm.requestActivate(modelIndex); }
        else if (active && Plasmoid.configuration.minimizeActiveTaskOnClick) tm.requestToggleMinimized(modelIndex);
        else tm.requestActivate(modelIndex);
    }

    // concentric inside the box: its radius less the inset
    readonly property int inset: 3
    Rectangle {
        anchors.fill: parent
        anchors.margins: entry.inset
        radius: Math.max(4, entry.r.tile * 0.26 - entry.inset)
        color: tap.pressed ? Qt.rgba(entry.r.accent.r, entry.r.accent.g, entry.r.accent.b, 0.25)
               : hover.hovered ? (entry.r.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.10))
               : entry.active ? (entry.r.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)) : Qt.rgba(0, 0, 0, 0)
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    Rectangle { // the focused window: a short accent bar on the screen-edge side
        visible: entry.active
        width: 3; height: Math.round(entry.height * 0.4)
        radius: 1.5
        x: entry.r.side === PlasmaCore.Types.RightEdge ? entry.width - entry.inset - width - 2 : entry.inset + 2
        anchors.verticalCenter: parent.verticalCenter
        color: entry.r.accent
    }
    Kirigami.Icon {
        anchors.centerIn: parent
        width: Math.min(Math.round(Plasmoid.configuration.iconSize * 0.66), entry.height - 10)
        height: width
        roundToIconSize: false
        source: entry.model.decoration
        opacity: entry.model.IsMinimized === true ? 0.5 : 1
    }

    PlasmaCore.ToolTipArea {
        id: tipArea
        anchors.fill: parent
        active: !entry.dragging && !entry.r.menuOpen
        location: Plasmoid.location
        interactive: true
        mainItem: TaskToolTip {
            id: tip
            r: entry.r
            task: entry.owner
            child: entry.index
            childModel: entry.model
            hideFn: () => tipArea.hideImmediately()
            active: tipArea.containsMouse
        }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            entry.r.windowsHovered(entry.model.WinIdList, hovered);
            if (hovered) card.refresh(); // the drag image has to be ready before a drag starts
        }
    }
    TapHandler {
        id: tap
        acceptedButtons: Qt.LeftButton
        onTapped: entry.activate()
    }
    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: entry.r.tasksModel.requestClose(entry.modelIndex)
    }
    MouseArea { // accepts the click, so Plasma's own panel menu stays closed
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
    }

    DragCard {
        id: card
        x: -10000 // out of view, only grabbed
        icon: entry.model.decoration
        title: entry.model.display || ""
    }
    // onto a workspace thumbnail moves just this window there; over one switches, and a drop
    // anywhere after that brings the window along
    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.MoveAction
    Drag.mimeData: ({ [entry.r.windowMime]: String(entry.winId) })
    Drag.imageSource: card.image
    Drag.hotSpot: Qt.point(card.pad + 24, card.pad + 22)
    Drag.active: dragH.active
    Drag.onDragFinished: dropAction => {
        entry.dragging = false;
        entry.r.endWindowDrag([String(entry.winId)], dropAction === Qt.IgnoreAction);
    }
    DragHandler {
        id: dragH
        target: null
        enabled: entry.winId !== undefined
        onActiveChanged: if (active && !entry.dragging) {
            entry.dragging = true;
            tipArea.hideImmediately();
            entry.r.beginWindowDrag();
        }
    }
}
