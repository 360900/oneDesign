import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

// The One rail: workspace thumbnails on top, pinned and running apps below.
// Items keep their own size and stack from the top, so the panel never spreads them.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation

    readonly property bool dark: Kirigami.Theme.textColor.hsvValue > 0.5
    readonly property int tile: Plasmoid.configuration.tileSize
    readonly property color fill: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.55)
    readonly property color fillHover: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0.2, 0.28, 0.4, 0.2)
    readonly property int gap: 6
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color fillPressed: Qt.tint(fillHover, Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.45 : 0.30))

    TaskManager.VirtualDesktopInfo { id: vdi }
    TaskManager.ActivityInfo { id: activityInfo }

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

    // Pinned launchers merged with their running windows: feeds the app column
    TaskManager.TasksModel {
        id: appModel
        // Same switches as KDE's task manager
        virtualDesktop: vdi.currentDesktop
        activity: activityInfo.currentActivity
        screenGeometry: Plasmoid.containment.screenGeometry
        filterByVirtualDesktop: Plasmoid.configuration.onlyCurrentDesktop
        filterByScreen: Plasmoid.configuration.onlyCurrentScreen
        filterByActivity: Plasmoid.configuration.onlyCurrentActivity
        filterMinimized: Plasmoid.configuration.onlyMinimized
        groupMode: Plasmoid.configuration.grouping === 0 ? TaskManager.TasksModel.GroupDisabled : TaskManager.TasksModel.GroupApplications
        sortMode: [TaskManager.TasksModel.SortManual, TaskManager.TasksModel.SortAlpha,
                   TaskManager.TasksModel.SortVirtualDesktop, TaskManager.TasksModel.SortActivity][Plasmoid.configuration.sorting] ?? TaskManager.TasksModel.SortManual
        separateLaunchers: Plasmoid.configuration.separateLaunchers
        launchInPlace: true
        launcherList: Plasmoid.configuration.launchers
    }

    // Pin, unpin and reorder are written back so they survive a restart
    Connections {
        target: appModel
        function onLauncherListChanged() {
            const l = appModel.launcherList;
            if (JSON.stringify(l) !== JSON.stringify(Plasmoid.configuration.launchers)) Plasmoid.configuration.launchers = l;
        }
    }
    // Rail and drawer share one pinned list: any change here (rail, settings page) reaches the drawer live
    Connections {
        target: Plasmoid.configuration
        function onLaunchersChanged() { root.shareLaunchers(Plasmoid.configuration.launchers, "org.onedesign.drawer") }
    }
    function shareLaunchers(list, other) {
        const c = Plasmoid.containment;
        for (const a of (c ? c.applets : [])) {
            if (a.pluginName === other && JSON.stringify(a.configuration.launchers) !== JSON.stringify(list))
                a.configuration.launchers = list;
        }
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source, data) => {
            if (source.indexOf("sh '" + root.actionsScript) === 0) {
                root.actionsReady((data.stdout || "").split("\n").filter(l => l.indexOf("\t") > 0)
                    .map(l => ({ name: l.split("\t")[0], cmd: l.split("\t").slice(1).join("\t") })));
            }
            disconnectSource(source);
        }
    }
    readonly property string actionsScript: Qt.resolvedUrl("../actions.sh").toString().replace("file://", "")
    signal actionsReady(var acts)
    function fetchActions(url) {
        exec.connectSource("sh '" + actionsScript + "' '" + url + "'");
    }
    function kwin(args) {
        exec.connectSource("qdbus6 org.kde.KWin " + args);
    }
    function switchTo(n) {
        kwin("/KWin org.kde.KWin.setCurrentDesktop " + n);
    }
    // Workspaces are stacked in one column, so KWin's slide animation runs vertically too
    function stackDesktops() {
        kwin("/VirtualDesktopManager org.kde.KWin.VirtualDesktopManager.rows " + Math.max(1, vdi.numberOfDesktops));
    }
    Connections {
        target: vdi
        function onNumberOfDesktopsChanged() { root.stackDesktops() }
    }
    function addDesktop() {
        const n = vdi.numberOfDesktops;
        kwin("/VirtualDesktopManager org.kde.KWin.VirtualDesktopManager.createDesktop " + n + " 'Desktop " + (n + 1) + "'");
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

    // Panel visibility: always, auto-hide (slides away, back on hover at the edge), or windows may cover it
    Connections {
        target: Plasmoid.configuration
        function onHideModeChanged() {
            const mode = ["none", "autohide", "windowscover"][Plasmoid.configuration.hideMode] || "none";
            exec.connectSource("qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
                + "'var p = panels().filter(function (x) { return x.id == " + Plasmoid.containment.id + "; })[0]; if (p) { p.hiding = \"" + mode + "\"; }'");
        }
    }
    Timer {
        id: lengthTimer
        interval: 250
        onTriggered: {
            if (!Plasmoid.configuration.fillWhenMaximized) return;
            const id = Plasmoid.containment.id;
            const inset = Screen.height - 32;
            const body = root.maximized
                ? 'p.lengthMode = "fill";'
                : 'p.lengthMode = "custom"; p.alignment = "center"; p.minimumLength = ' + inset + '; p.maximumLength = ' + inset + ';';
            exec.connectSource("qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
                + "'var p = panels().filter(function (x) { return x.id == " + id + "; })[0]; if (p) { " + body + " }'");
        }
    }
    Component.onCompleted: { recountMaximized(); stackDesktops(); }

    // Wheel over the apps: activate the next or previous running app
    function cycleTasks(dir) {
        const R = TaskManager.AbstractTasksModel;
        const run = [];
        let cur = -1;
        for (let i = 0; i < appModel.count; i++) {
            const ix = appModel.makeModelIndex(i);
            if (appModel.data(ix, R.IsWindow) !== true && appModel.data(ix, R.IsGroupParent) !== true) continue;
            if (appModel.data(ix, R.IsActive) === true) cur = run.length;
            run.push(i);
        }
        if (!run.length) return;
        const next = run[((cur < 0 ? (dir > 0 ? -1 : 0) : cur) + dir + run.length) % run.length];
        const grp = appModel.data(appModel.makeModelIndex(next), R.IsGroupParent) === true;
        appModel.requestActivate(grp ? appModel.makeModelIndex(next, 0) : appModel.makeModelIndex(next));
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

        // Fetches the app's own actions (private window and so on), then shows the menu
        function openMenu(app) {
            menu.cur = app;
            menu.pinned = appModel.launcherPosition(app.model.LauncherUrlWithoutIcon) >= 0;
            root.fetchActions(app.model.LauncherUrlWithoutIcon);
        }
        Connections {
            target: root
            function onActionsReady(acts) {
                const app = menu.cur;
                const items = acts.map(a => ({ id: "action", text: a.name, cmd: a.cmd, icon: "", separator: false }));
                if (items.length) items.push({ id: "", text: "", icon: "", separator: true });
                items.push({ id: "new", text: "New window", icon: "window-new-symbolic", separator: false });
                items.push({ id: "pin", text: menu.pinned ? "Unpin" : "Pin to rail", icon: menu.pinned ? "window-unpin-symbolic" : "pin-symbolic", separator: false });
                if (app.running) {
                    items.push({ id: "", text: "", icon: "", separator: true });
                    items.push({ id: "close", text: "Close", icon: "window-close-symbolic", separator: false });
                }
                menu.model = items;
                menu.visualParent = app;
                menu.openRelative();
            }
        }

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

        MouseArea {
            // wheel over the apps cycles through the running ones
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: col.top
            anchors.topMargin: appCol.y
            height: appCol.height
            enabled: Plasmoid.configuration.wheelSwitchTasks
            acceptedButtons: Qt.NoButton
            onWheel: wheel => root.cycleTasks(wheel.angleDelta.y < 0 ? 1 : -1)
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
                Repeater {
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
                            opacity: ws.current || hover.hovered ? 1 : 0.72
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
            Column {
                id: appCol
                Layout.fillWidth: true
                Layout.row: Plasmoid.configuration.workspacesFirst ? 2 : 0
                visible: Plasmoid.configuration.showApps
                spacing: Plasmoid.configuration.appSpacing
                Repeater {
                    model: appModel
                    delegate: Item {
                        id: app
                        required property int index
                        required property var model
                        readonly property bool running: model.IsWindow === true || model.IsGroupParent === true
                        readonly property bool active: model.IsActive === true
                        width: parent.width
                        height: root.tile
                        visible: Plasmoid.configuration.showPinned || running
                        z: dragH.active ? 10 : 0
                        property int startIndex: 0
                        readonly property real step: root.tile + appCol.spacing
                        readonly property real dy: dragH.active ? dragH.centroid.scenePosition.y - dragH.centroid.scenePressPosition.y : 0

                        Item {
                            id: body
                            width: parent.width; height: parent.height
                            y: dragH.active ? app.dy - (app.index - app.startIndex) * app.step : 0
                            opacity: dragH.active ? 0.85 : 1
                            Behavior on y { enabled: !dragH.active; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                        Rectangle { // running tab on the screen edge; taller when focused
                            x: 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3.5
                            height: app.active ? 28 : 14
                            radius: 2
                            color: root.accent
                            visible: app.running && Plasmoid.configuration.showRunningIndicator
                            Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                            // flat on the screen edge, rounded inward
                            Rectangle { width: 2; height: parent.height; color: parent.color }
                        }
                        Rectangle { // resting tile: shows behind icons that are not full-bleed
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.tile; height: root.tile
                            radius: root.tile * 0.26
                            color: root.fill
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, root.dark ? 0.12 : 0.6)
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Plasmoid.configuration.iconSize; height: width
                            roundToIconSize: false
                            source: app.model.decoration
                        }
                        Rectangle { // hover and press recolor the whole tile, icon included
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.tile; height: root.tile
                            radius: root.tile * 0.26
                            color: appTap.pressed ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
                                   : appHover.hovered ? (root.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.10))
                                   : app.active ? (root.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)) : (root.dark ? Qt.rgba(1, 1, 1, 0) : Qt.rgba(0, 0, 0, 0))
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        Rectangle { // asks for attention
                            id: attention
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.tile; height: root.tile
                            radius: root.tile * 0.26
                            color: root.accent
                            opacity: 0
                            visible: Plasmoid.configuration.highlightAttention && app.model.IsDemandingAttention === true
                            SequentialAnimation on opacity {
                                running: attention.visible
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.5; duration: 600 }
                                NumberAnimation { to: 0.1; duration: 600 }
                            }
                        }
                        }
                        onDyChanged: if (dragH.active) {
                            const t = Math.max(0, Math.min(appModel.count - 1, Math.round(startIndex + dy / step)));
                            if (t !== index) appModel.move(index, t);
                        }
                        PlasmaCore.ToolTipArea {
                            anchors.fill: parent
                            active: Plasmoid.configuration.showToolTips && !dragH.active
                            location: Plasmoid.location
                            mainText: app.model.AppName || app.model.display || ""
                            subText: app.running && app.model.IsGroupParent !== true ? (app.model.display || "") : ""
                        }
                        HoverHandler { id: appHover }
                        DragHandler {
                            id: dragH
                            enabled: appModel.sortMode === TaskManager.TasksModel.SortManual
                            target: null
                            acceptedButtons: Qt.LeftButton
                            xAxis.enabled: false
                            onActiveChanged: {
                                if (active) app.startIndex = app.index;
                                else appModel.syncLaunchers(); // move() alone does not touch the launcher list
                            }
                        }
                        MouseArea { // accepts the click, so Plasma's own panel menu stays closed
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            onClicked: rail.openMenu(app)
                        }
                        TapHandler {
                            id: appTap
                            acceptedButtons: Qt.LeftButton
                            onTapped: {
                                const idx = appModel.makeModelIndex(app.index);
                                if (!app.running) appModel.requestNewInstance(idx);
                                else if (app.active && app.model.IsGroupParent !== true) appModel.requestToggleMinimized(idx);
                                else appModel.requestActivate(app.model.IsGroupParent === true ? appModel.makeModelIndex(app.index, 0) : idx);
                            }
                        }
                        TapHandler {
                            acceptedButtons: Qt.MiddleButton
                            onTapped: {
                                const idx = appModel.makeModelIndex(app.index);
                                switch (Plasmoid.configuration.middleClick) {
                                case 1: if (app.running) appModel.requestClose(idx); break;
                                case 2: appModel.requestNewInstance(idx); break;
                                case 3: if (app.running) appModel.requestToggleMinimized(idx); break;
                                case 4: if (app.running) appModel.requestVirtualDesktops(idx, [vdi.currentDesktop]); break;
                                }
                            }
                        }
                    }
                }
            }
        }

        // A native menu: item popups would be clipped to the narrow panel window
        PlasmaExtras.ModelContextMenu {
            id: menu
            property var cur: null
            property bool pinned: false
            onClicked: m => {
                const idx = appModel.makeModelIndex(menu.cur.index);
                switch (m.id) {
                case "action": exec.connectSource(m.cmd); break;
                case "new": appModel.requestNewInstance(idx); break;
                case "pin":
                    if (menu.pinned) appModel.requestRemoveLauncher(menu.cur.model.LauncherUrlWithoutIcon);
                    else appModel.requestAddLauncher(menu.cur.model.LauncherUrl);
                    break;
                case "close": appModel.requestClose(idx); break;
                }
            }
        }
    }
}
