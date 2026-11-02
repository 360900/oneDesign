import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.kicker as Kicker
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

// The One drawer: opens beside the rail, full height. Search first; otherwise running and pinned apps.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    toolTipMainText: i18n("Apps")
    hideOnWindowDeactivate: true

    property string text: ""
    property bool open: false
    property real anchorX: 68
    // Super (or any "activate launcher" shortcut) toggles the drawer; both signals can fire, so debounce
    property double lastToggle: 0
    property bool ready: false
    Timer { interval: 3000; running: true; onTriggered: root.ready = true }
    function toggleDrawer() {
        if (!ready || Date.now() - lastToggle < 500) return;
        lastToggle = Date.now();
        root.anchorX = Screen.virtualX + (root.Window.window ? root.Window.window.width : 68);
        root.open = !root.open;
    }
    Connections { target: Plasmoid; function onActivated() { root.toggleDrawer() } }
    onExpandedChanged: if (root.expanded) { root.expanded = false; root.toggleDrawer(); }
    readonly property bool dark: Kirigami.Theme.textColor.hsvValue > 0.5
    readonly property color fill: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.55)
    readonly property color fillHover: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0.2, 0.28, 0.4, 0.2)
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color fillPressed: Qt.tint(fillHover, Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.45 : 0.30))
    readonly property int drawerW: Plasmoid.configuration.drawerWidth
    // Same size as the old popup (screen height - 52 in total), centered: 26px from the top and from the bottom
    readonly property real frameV: dlg.margins ? dlg.margins.top + dlg.margins.bottom : 18
    readonly property int drawerH: Math.max(400, Math.round(Screen.height - 52 - frameV))

    TaskManager.TasksModel {
        id: appModel
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false
        groupMode: Plasmoid.configuration.groupApps ? TaskManager.TasksModel.GroupApplications : TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortManual
        separateLaunchers: false
        launchInPlace: true
        launcherList: Plasmoid.configuration.launchers
    }

    Kicker.RunnerModel {
        id: runner
        appletInterface: root
        mergeResults: true
        runners: Plasmoid.configuration.appsOnlySearch ? ["services"] : []
        query: root.open ? root.text : ""
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source, data) => {
            if (source === "id -un") user.name = (data.stdout || "").trim();
            else if (source.indexOf("sh '" + root.actionsScript) === 0)
                root.showMenu((data.stdout || "").split("\n").filter(l => l.indexOf("\t") > 0)
                    .map(l => ({ name: l.split("\t")[0], cmd: l.split("\t").slice(1).join("\t") })));
            disconnectSource(source);
        }
        Component.onCompleted: connectSource("id -un")
    }
    QtObject { id: user; property string name: "" }

    // Rail and drawer share one pinned list: after a local change, write it to the other widget too
    function syncLaunchers(list, other) {
        const js = 'panels().forEach(function (p) { p.widgetIds.forEach(function (i) { var w = p.widgetById(i); '
            + 'if (w.type == "%s") { w.currentConfigGroup = ["General"]; w.writeConfig("launchers", ' + JSON.stringify(list) + '); } }); });';
        exec.connectSource("qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '" + js.replace("%s", other) + "'");
    }

    // Right-click menu, the same as on the rail
    readonly property string actionsScript: Qt.resolvedUrl("../actions.sh").toString().replace("file://", "")
    Connections {
        target: appModel
        function onLauncherListChanged() {
            const l = appModel.launcherList;
            if (JSON.stringify(l) !== JSON.stringify(Plasmoid.configuration.launchers)) {
                Plasmoid.configuration.launchers = l;
                root.syncLaunchers(l, "org.onedesign.rail");
            }
        }
    }
    property var menuRow: null
    property bool menuPinned: false
    function openMenu(row) {
        menuRow = row;
        menuPinned = appModel.launcherPosition(row.model.LauncherUrlWithoutIcon) >= 0;
        exec.connectSource("sh '" + actionsScript + "' '" + row.model.LauncherUrlWithoutIcon + "'");
    }
    function showMenu(acts) {
        const items = acts.map(a => ({ id: "action", text: a.name, cmd: a.cmd, icon: "", separator: false }));
        if (items.length) items.push({ id: "", text: "", icon: "", separator: true });
        items.push({ id: "new", text: i18n("New window"), icon: "window-new-symbolic", separator: false });
        items.push({ id: "pin", text: menuPinned ? i18n("Unpin") : i18n("Pin to rail"), icon: menuPinned ? "window-unpin-symbolic" : "pin-symbolic", separator: false });
        if (menuRow.running) {
            items.push({ id: "", text: "", icon: "", separator: true });
            items.push({ id: "close", text: i18n("Close"), icon: "window-close-symbolic", separator: false });
        }
        menu.model = items;
        menu.visualParent = menuRow;
        menu.openRelative();
    }
    PlasmaExtras.ModelContextMenu {
        id: menu
        onClicked: m => {
            const idx = appModel.makeModelIndex(root.menuRow.index);
            switch (m.id) {
            case "action": exec.connectSource(m.cmd); root.open = false; break;
            case "new": appModel.requestNewInstance(idx); root.open = false; break;
            case "pin":
                if (root.menuPinned) appModel.requestRemoveLauncher(root.menuRow.model.LauncherUrlWithoutIcon);
                else appModel.requestAddLauncher(root.menuRow.model.LauncherUrl);
                break;
            case "close": appModel.requestClose(idx); break;
            }
        }
    }

    function run(cmd) {
        exec.connectSource(cmd);
        root.open = false;
    }
    function openApp(i, running, active, group) {
        const idx = appModel.makeModelIndex(i);
        if (!running) appModel.requestNewInstance(idx);
        else if (active && !group) appModel.requestToggleMinimized(idx);
        else appModel.requestActivate(group ? appModel.makeModelIndex(i, 0) : idx);
        root.open = false;
    }

    fullRepresentation: MouseArea {
        id: btn
        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
            || Plasmoid.location === PlasmaCore.Types.LeftEdge || Plasmoid.location === PlasmaCore.Types.RightEdge
        implicitWidth: 44 + Kirigami.Units.smallSpacing * 2
        implicitHeight: 44 + Kirigami.Units.smallSpacing * 2
        Layout.minimumWidth: vertical ? 0 : implicitWidth
        Layout.minimumHeight: vertical ? implicitHeight : 0
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        Layout.fillWidth: vertical
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: { root.anchorX = Screen.virtualX + (btn.Window.window ? btn.Window.window.width : 68); root.open = !root.open; }

        Rectangle {
            anchors.centerIn: parent
            width: 44; height: 44
            radius: btn.vertical ? 12 : 22
            color: root.open || btn.pressed ? root.fillPressed : btn.containsMouse ? root.fillHover : root.fill
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, root.dark ? 0.12 : 0.6)
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        Grid { // four solid squares, as in the renders
            anchors.centerIn: parent
            columns: 2
            spacing: 3
            Repeater {
                model: 4
                Rectangle { width: 8; height: 8; radius: 1.5; color: Kirigami.Theme.textColor }
            }
        }
    }

    // A window of our own, so it can sit flush against the rail and level with it
    PlasmaCore.Dialog {
        id: dlg
        visible: root.open
        visualParent: null
        location: PlasmaCore.Types.LeftEdge
        hideOnWindowDeactivate: Plasmoid.configuration.closeWhenUnfocused
        flags: Qt.WindowStaysOnTopHint
        x: root.anchorX
        y: Screen.virtualY + 26
        onVisibleChanged: if (!visible) root.open = false
        mainItem: Drawer {}
    }

    component Drawer: Item {
        id: drawer
        width: root.drawerW
        height: root.drawerH
        Keys.onEscapePressed: root.open = false

        readonly property bool searching: root.text.length > 0

        Connections {
            target: root
            function onOpenChanged() {
                if (root.open) {
                    search.text = "";
                    search.forceActiveFocus();
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Kirigami.SearchField {
                id: search
                Layout.fillWidth: true
                Layout.bottomMargin: 6
                placeholderText: i18n("Search apps and files")
                autoAccept: false
                onTextChanged: root.text = text
                onAccepted: if (runner.count > 0 && runner.modelForRow(0).count > 0) {
                    runner.modelForRow(0).trigger(0, "", null);
                    root.open = false;
                }
            }

            // ---- idle: running, then pinned
            Flickable {
                id: idle
                visible: !drawer.searching
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: idleCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                GridLayout {
                    id: idleCol
                    width: idle.width
                    columns: 1
                    rowSpacing: 2

                    Column {
                        Layout.fillWidth: true
                        Layout.row: Plasmoid.configuration.runningFirst ? 0 : 1
                        visible: Plasmoid.configuration.showRunning
                        spacing: 2
                        Text {
                            text: i18n("Running")
                            visible: runningCount.n > 0
                            leftPadding: 10; topPadding: 6; bottomPadding: 2
                            color: Kirigami.Theme.textColor; opacity: 0.6
                            font.pixelSize: 12; font.weight: Font.Bold
                        }
                        Repeater {
                            model: appModel
                            delegate: AppRow { run: true }
                        }
                    }
                    Column {
                        Layout.fillWidth: true
                        Layout.row: Plasmoid.configuration.runningFirst ? 1 : 0
                        visible: Plasmoid.configuration.showPinned
                        spacing: 2
                        Text {
                            text: i18n("Pinned")
                            visible: pinnedCount.n > 0
                            leftPadding: 10; topPadding: 14; bottomPadding: 2
                            color: Kirigami.Theme.textColor; opacity: 0.6
                            font.pixelSize: 12; font.weight: Font.Bold
                        }
                        Repeater {
                            model: appModel
                            delegate: AppRow { run: false }
                        }
                    }
                }
            }

            // ---- searching: merged runner results
            ListView {
                id: results
                visible: drawer.searching
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: runner.count > 0 ? runner.modelForRow(0) : null
                spacing: 2
                delegate: Row {
                    id: res
                    required property int index
                    required property var model
                    width: ListView.view.width
                    height: 44
                    Item {
                        width: parent.width; height: parent.height
                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: Kirigami.Theme.textColor
                            opacity: rh.hovered ? 0.1 : res.ListView.isCurrentItem ? 0.07 : 0
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10; anchors.rightMargin: 10
                            spacing: 12
                            Kirigami.Icon { source: res.model.decoration; Layout.preferredWidth: 24; Layout.preferredHeight: 24 }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    text: res.model.display; elide: Text.ElideRight
                                    color: Kirigami.Theme.textColor; font.pixelSize: 14
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: text.length > 0
                                    text: res.model.description || ""; elide: Text.ElideRight
                                    color: Kirigami.Theme.textColor; opacity: 0.6; font.pixelSize: 11
                                }
                            }
                        }
                        HoverHandler { id: rh }
                        TapHandler {
                            onTapped: {
                                results.model.trigger(res.index, "", null);
                                root.open = false;
                            }
                        }
                    }
                }
            }

            // ---- user row
            Rectangle { visible: Plasmoid.configuration.showUserRow; Layout.fillWidth: true; Layout.preferredHeight: 1; color: Kirigami.Theme.textColor; opacity: 0.14; Layout.topMargin: 4 }
            RowLayout {
                visible: Plasmoid.configuration.showUserRow
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                Layout.leftMargin: 6; Layout.rightMargin: 4
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32
                    radius: 16
                    color: root.accent
                    Text {
                        anchors.centerIn: parent
                        text: user.name.length ? user.name[0].toUpperCase() : ""
                        color: Kirigami.Theme.highlightedTextColor
                        font.pixelSize: 15; font.weight: Font.Bold
                    }
                }
                Item { Layout.fillWidth: true; visible: !Plasmoid.configuration.showUserName }
                Text {
                    Layout.fillWidth: true
                    visible: Plasmoid.configuration.showUserName
                    text: user.name
                    elide: Text.ElideRight
                    color: Kirigami.Theme.textColor
                    font.pixelSize: 14; font.weight: Font.DemiBold
                }
                Repeater {
                    model: [
                        { icon: "preferences-system-symbolic", cmd: "systemsettings", on: Plasmoid.configuration.showSettingsButton },
                        { icon: "system-lock-screen-symbolic", cmd: "loginctl lock-session", on: Plasmoid.configuration.showLockButton },
                        { icon: "system-shutdown-symbolic", cmd: "qdbus6 org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptShutDown", on: Plasmoid.configuration.showPowerButton }
                    ].filter(b => b.on)
                    delegate: Item {
                        required property var modelData
                        Layout.preferredWidth: 32; Layout.preferredHeight: 32
                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: Kirigami.Theme.textColor
                            opacity: bh.hovered ? 0.12 : 0
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 16; height: 16
                            source: parent.modelData.icon
                            isMask: true
                            color: Kirigami.Theme.textColor
                        }
                        HoverHandler { id: bh }
                        TapHandler { onTapped: root.run(parent.modelData.cmd) }
                    }
                }
            }
        }
    }

    // counts for the group labels
    QtObject { id: runningCount; property int n: 0 }
    QtObject { id: pinnedCount; property int n: 0 }
    function recount() {
        let r = 0, p = 0;
        for (let i = 0; i < appModel.count; i++) {
            const ix = appModel.makeModelIndex(i);
            const running = appModel.data(ix, TaskManager.AbstractTasksModel.IsWindow) === true
                || appModel.data(ix, TaskManager.AbstractTasksModel.IsGroupParent) === true;
            if (running) r++; else p++;
        }
        runningCount.n = r;
        pinnedCount.n = p;
    }
    Connections {
        target: appModel
        function onCountChanged() { root.recount() }
        function onDataChanged() { root.recount() }
        function onModelReset() { root.recount() }
    }
    Component.onCompleted: recount()

    component AppRow: Item {
        id: row
        required property int index
        required property var model
        required property bool run
        readonly property bool running: model.IsWindow === true || model.IsGroupParent === true
        readonly property bool active: model.IsActive === true
        readonly property bool shown: run ? (running && Plasmoid.configuration.showRunning) : (!running && Plasmoid.configuration.showPinned)
        visible: shown
        width: parent ? parent.width : 0
        height: shown ? 44 : 0

        Rectangle { // active: fill and an accent tab on the drawer's inner edge
            anchors.fill: parent
            radius: 12
            color: Kirigami.Theme.textColor
            opacity: ah.hovered ? 0.1 : row.active && row.run ? 0.07 : 0
        }
        Rectangle {
            visible: row.run && row.active
            x: -6; width: 3.5; height: 24; radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: root.accent
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 10
            spacing: 12
            Kirigami.Icon { source: row.model.decoration; Layout.preferredWidth: Plasmoid.configuration.iconSize; Layout.preferredHeight: Plasmoid.configuration.iconSize }
            Text {
                Layout.fillWidth: true
                text: row.model.AppName || row.model.display
                elide: Text.ElideRight
                color: Kirigami.Theme.textColor
                font.pixelSize: 14
                font.weight: row.run && row.active ? Font.DemiBold : Font.Normal
            }
            Text {
                visible: row.run && (row.model.ChildCount || 0) > 1
                text: i18n("%1 windows", row.model.ChildCount)
                color: Kirigami.Theme.textColor; opacity: 0.55; font.pixelSize: 11
            }
        }
        HoverHandler { id: ah }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: root.openMenu(row)
        }
        TapHandler {
            onTapped: root.openApp(row.index, row.running, row.active, row.model.IsGroupParent === true)
        }
    }
}
