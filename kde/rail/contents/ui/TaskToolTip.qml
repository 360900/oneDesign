/*
    Task tooltip: app name for launchers; for running apps one entry per window with a live
    thumbnail, close button and window highlight, plus media and volume controls, as in KDE's
    task manager (plasma-desktop applets/taskmanager/qml/ToolTipDelegate.qml, ToolTipInstance.qml).
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQml.Models
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.mpris as Mpris
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.pipewire as PipeWire

Item {
    id: tip

    required property var r
    required property Item task
    property bool active: false        // the pointer is on the app tile, or the tooltip was opened by a click
    property bool dragging: false      // a window preview is being dragged out
    // one window of a group only, for its entry in the app's expanded box: its row and model data
    property int child: -1
    property var childModel: null
    property var hideFn: null          // closes the tooltip this sits in, when not the app tile's
    readonly property bool hovered: tipHover.hovered || dragging
    function hide() { if (hideFn) hideFn(); else task.hideToolTip(); }
    // Thumbnails stream while the tooltip is in use: the pointer on the tile, on the tooltip itself or
    // dragging out of it. A short hold covers the gap between tile and tooltip, so no placeholder flashes.
    readonly property bool wanted: active || dragging || tipHover.hovered
    property bool live: false
    onWantedChanged: if (wanted) { liveHold.stop(); live = true; } else liveHold.restart()
    Timer { id: liveHold; interval: 300; onTriggered: tip.live = false }
    HoverHandler { id: tipHover }

    readonly property var m: task ? task.model : null
    readonly property bool isGroup: m ? m.IsGroupParent === true : false
    readonly property bool isLauncher: m ? m.IsLauncher === true : false
    readonly property var player: (m && Plasmoid.configuration.tooltipControls)
        ? r.mpris2Source.playerForLauncherUrl(m.LauncherUrlWithoutIcon, m.AppPid) : null
    readonly property bool thumbs: Plasmoid.configuration.showToolTips

    implicitWidth: col.implicitWidth + Kirigami.Units.smallSpacing * 2
    implicitHeight: col.implicitHeight + Kirigami.Units.smallSpacing * 2

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing

        // launcher, or a running app with the tooltip previews switched off
        RowLayout {
            visible: (tip.isLauncher || !tip.thumbs) && tip.child < 0
            spacing: Kirigami.Units.smallSpacing * 2
            Layout.margins: Kirigami.Units.smallSpacing
            Layout.maximumWidth: Kirigami.Units.gridUnit * 18
            ColumnLayout {
                spacing: 0
                Kirigami.Heading {
                    level: 3
                    text: tip.m ? (tip.m.AppName || tip.m.display || "") : ""
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                PlasmaComponents3.Label {
                    visible: text.length > 0
                    text: !tip.m ? "" : tip.isLauncher ? (tip.m.GenericName || "")
                        : tip.isGroup ? i18np("%1 window", "%1 windows", tip.m.ChildCount || 0) : (tip.m.display || "")
                    opacity: 0.75
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    Layout.fillWidth: true
                }
            }
        }

        // one entry per window: the group's children, or the task itself
        Repeater {
            model: DelegateModel {
                model: (tip.thumbs && tip.isGroup && tip.child < 0 && tip.task) ? tip.r.tasksModel : null
                rootIndex: tip.isGroup && tip.task ? tip.r.tasksModel.makeModelIndex(tip.task.index) : null
                delegate: Window {}
            }
        }
        Loader {
            active: tip.thumbs && !tip.isGroup && !tip.isLauncher && tip.m !== null
            visible: active
            sourceComponent: Window { index: 0; model: tip.m }
        }
        Loader {
            active: tip.child >= 0 && tip.childModel !== null
            visible: active
            sourceComponent: Window { index: tip.child; model: tip.childModel }
        }

        // media controls
        RowLayout {
            visible: tip.player !== null && tip.player.canControl === true && !tip.isLauncher && tip.child < 0
            Layout.fillWidth: true
            spacing: 0
            ColumnLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 10
                spacing: 0
                PlasmaComponents3.Label { text: tip.player ? (tip.player.track || "") : ""; elide: Text.ElideRight; Layout.fillWidth: true; font.weight: Font.DemiBold }
                PlasmaComponents3.Label { text: tip.player ? (tip.player.artist || "") : ""; elide: Text.ElideRight; Layout.fillWidth: true; opacity: 0.75 }
            }
            PlasmaComponents3.ToolButton {
                enabled: tip.player && tip.player.canGoPrevious
                icon.name: "media-skip-backward"
                onClicked: tip.player.Previous()
            }
            PlasmaComponents3.ToolButton {
                readonly property bool playing: tip.player && tip.player.playbackStatus === Mpris.PlaybackStatus.Playing
                enabled: tip.player && (playing ? tip.player.canPause : tip.player.canPlay)
                icon.name: playing ? "media-playback-pause" : "media-playback-start"
                onClicked: playing ? tip.player.Pause() : tip.player.Play()
            }
            PlasmaComponents3.ToolButton {
                enabled: tip.player && tip.player.canGoNext
                icon.name: "media-skip-forward"
                onClicked: tip.player.Next()
            }
        }

        // volume of the app's streams
        RowLayout {
            visible: Plasmoid.configuration.tooltipControls && tip.task && tip.task.hasAudioStream === true && !tip.isLauncher && tip.child < 0
            Layout.fillWidth: true
            PlasmaComponents3.ToolButton {
                icon.name: tip.task && tip.task.muted ? "audio-volume-muted" : "audio-volume-high"
                checkable: true
                checked: tip.task ? tip.task.muted === true : false
                onClicked: tip.task.toggleMuted()
            }
            PlasmaComponents3.Slider {
                Layout.fillWidth: true
                from: 0; to: tip.r.normalVolume
                value: tip.task && tip.task.audioStreams.length ? tip.task.audioStreams[0].volume : 0
                onMoved: { for (const s of tip.task.audioStreams) s.setVolume(value); }
            }
        }
    }

    component Window: ColumnLayout {
        id: win
        required property int index
        required property var model
        readonly property var winId: (model.WinIdList || [])[0]
        readonly property var modelIndex: tip.isGroup ? tip.r.tasksModel.makeModelIndex(tip.task.index, index)
                                                      : tip.r.tasksModel.makeModelIndex(tip.task.index)
        readonly property real thumbW: Kirigami.Units.gridUnit * 14
        spacing: Kirigami.Units.smallSpacing
        // the entry can go away mid-drag when its window closes
        Component.onDestruction: if (tip.dragging) { tip.dragging = false; tip.r.endWindowDrag([], false); }
        Layout.margins: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: win.thumbW
            Kirigami.Icon { source: win.model.decoration; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Kirigami.Units.iconSizes.small }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: win.model.display || ""
                elide: Text.ElideRight
                font.weight: win.model.IsActive === true ? Font.DemiBold : Font.Normal
                opacity: win.model.IsMinimized === true ? 0.6 : 1
            }
            PlasmaComponents3.ToolButton {
                icon.name: "window-close"
                display: PlasmaComponents3.AbstractButton.IconOnly
                text: i18nc("@action:button", "Close")
                onClicked: tip.r.tasksModel.requestClose(win.modelIndex)
            }
        }
        Item {
            id: frame
            visible: tip.thumbs
            Layout.preferredWidth: win.thumbW
            Layout.preferredHeight: Math.round(win.thumbW * 9 / 16)
            Rectangle { // placeholder until the first frame arrives
                anchors.fill: parent
                radius: Kirigami.Units.cornerRadius
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)
                visible: !(thumb.item && thumb.item.ready)
                Kirigami.Icon { anchors.centerIn: parent; width: Kirigami.Units.iconSizes.large; height: width; source: win.model.decoration }
            }
            Loader {
                id: thumb
                anchors.fill: parent
                active: tip.live && win.winId !== undefined && win.model.IsMinimized !== true
                sourceComponent: PipeWire.PipeWireSourceItem {
                    nodeId: request.nodeId
                    TaskManager.ScreencastingRequest { id: request; uuid: win.winId }
                }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: Kirigami.Units.cornerRadius + 3
                color: "transparent"
                border.width: 2
                border.color: Kirigami.Theme.highlightColor
                visible: winHover.hovered
            }
            HoverHandler {
                id: winHover
                onHoveredChanged: {
                    tip.r.windowsHovered(win.model.WinIdList, hovered);
                    if (hovered) card.refresh(); // the drag image has to be ready before a drag starts
                }
            }
            DragCard {
                id: card
                x: -10000 // out of view, only grabbed
                icon: win.model.decoration
                title: win.model.display || ""
            }
            // drag the preview onto a workspace thumbnail to move just this window there, or over one
            // to switch and then anywhere to bring the window along
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.MoveAction
            Drag.mimeData: ({ [tip.r.windowMime]: String(win.winId) })
            Drag.imageSource: card.image
            Drag.hotSpot: Qt.point(card.pad + 24, card.pad + 22)
            Drag.active: winDrag.active
            Drag.onDragFinished: dropAction => {
                tip.dragging = false;
                // a thumbnail takes the drop itself; anywhere else counts as a drop on this desktop
                tip.r.endWindowDrag([String(win.winId)], dropAction === Qt.IgnoreAction);
            }
            DragHandler {
                id: winDrag
                target: null
                enabled: win.winId !== undefined
                onActiveChanged: if (active && !tip.dragging) { tip.dragging = true; tip.r.beginWindowDrag(); }
            }
            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: { tip.r.cancelHighlightWindows(); tip.r.tasksModel.requestActivate(win.modelIndex); tip.hide(); }
            }
            TapHandler {
                acceptedButtons: Qt.MiddleButton
                onTapped: tip.r.tasksModel.requestClose(win.modelIndex)
            }
        }
    }
}
