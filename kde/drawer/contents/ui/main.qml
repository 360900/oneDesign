import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.kicker as Kicker
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.private.sessions as Sessions
import org.kde.milou as Milou
import org.kde.coreaddons as KCoreAddons
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

// The One drawer: opens beside the rail, full height. Search runs KRunner's own model, so Plasma Search
// settings (enabled plugins, favorites) apply as they do in KRunner. Idle: running, pinned and all apps.
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
    readonly property color fill: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.38)
    readonly property color fillHover: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0.2, 0.28, 0.4, 0.2)
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color fillPressed: Qt.tint(fillHover, Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.45 : 0.30))
    readonly property int drawerW: Plasmoid.configuration.drawerWidth
    // Same size as the old popup (screen height - 52 in total), centered: 26px from the top and from the bottom
    readonly property real frameV: dlg.margins ? dlg.margins.top + dlg.margins.bottom : 18
    readonly property int drawerH: Math.max(400, Math.round(Screen.height - 52 - frameV))

    // ---- running and pinned apps, shared with the rail
    TaskManager.VirtualDesktopInfo { id: vdi }
    TaskManager.ActivityInfo { id: activityInfo }
    Mpris.Mpris2Model { id: mpris2Source }
    TaskManager.TasksModel {
        id: appModel
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false
        groupMode: Plasmoid.configuration.groupApps ? TaskManager.TasksModel.GroupApplications : TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortManual
        separateLaunchers: true
        launchInPlace: true
        launcherList: Plasmoid.configuration.launchers
    }
    Connections {
        target: appModel
        function onLauncherListChanged() {
            const l = appModel.launcherList;
            if (JSON.stringify(l) !== JSON.stringify(Plasmoid.configuration.launchers)) Plasmoid.configuration.launchers = l;
        }
    }
    // Rail and drawer share one pinned list: any change here reaches the rail live
    Connections {
        target: Plasmoid.configuration
        function onLaunchersChanged() { root.shareLaunchers(Plasmoid.configuration.launchers, "org.onedesign.rail") }
    }
    function shareLaunchers(list, other) {
        const c = Plasmoid.containment;
        for (const a of (c ? c.applets : [])) {
            if (a.pluginName === other && JSON.stringify(a.configuration.launchers) !== JSON.stringify(list))
                a.configuration.launchers = list;
        }
    }
    // A desktop file url as a launcher entry: applications:<name> when it lives in an applications dir
    function launcherFor(desktopUrl) {
        const u = desktopUrl.toString();
        return u.indexOf("/applications/") >= 0 ? "applications:" + u.substring(u.lastIndexOf("/") + 1) : u;
    }
    function isPinned(launcher) { return appModel.launcherPosition(launcher) >= 0; }
    function togglePin(launcher) {
        if (isPinned(launcher)) appModel.requestRemoveLauncher(launcher);
        else appModel.requestAddLauncher(launcher);
    }

    // ---- TaskMenu helpers (same menu as the rail)
    readonly property alias tasksModel: appModel
    readonly property alias virtualDesktopInfo: vdi
    readonly property alias activityInfo: activityInfo
    readonly property alias mpris2Source: mpris2Source
    function foreachChildTask(callback, idx) {
        const n = appModel.rowCount(idx);
        if (n > 0) for (let i = 0; i < n; ++i) callback(appModel.index(i, 0, idx));
        else callback(idx);
    }

    // ---- search: KRunner's model and settings
    Milou.ResultsModel {
        id: search
        queryString: root.open ? root.text : ""
        limit: 15 // as in KRunner
    }

    // ---- all apps, by menu category
    Kicker.RootModel {
        id: allApps
        autoPopulate: false
        appletInterface: root
        flat: true
        sorted: true
        showSeparators: false
        showTopLevelItems: false
        showAllApps: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
        showFavoritesPlaceholder: false
    }

    // ---- app actions (jump list, recent files, edit, uninstall) for menus
    Kicker.SimpleFavoritesModel { id: appEntry }
    Instantiator {
        model: appEntry
        delegate: QtObject {
            required property var model
            Component.onCompleted: root.entryReady(model.actionList || [])
        }
    }
    property var pendingMenu: null
    function withAppActions(desktopId, fn) {
        pendingMenu = fn;
        appEntry.favorites = [];
        if (!desktopId) { entryReady([]); return; }
        appEntry.favorites = [desktopId];
    }
    function entryReady(actions) {
        const fn = pendingMenu;
        pendingMenu = null;
        if (fn) fn(actions);
    }
    function triggerAppAction(a) {
        appEntry.trigger(0, a.actionId, a.actionArgument);
        root.open = false;
    }

    // right-click on a running or pinned row
    function openTaskMenu(row) {
        const app = row.model.AppId || "";
        withAppActions(app ? (app.endsWith(".desktop") ? app : app + ".desktop") : "", actions => {
            const m = taskMenuComponent.createObject(root, { r: root, modelIndex: appModel.makeModelIndex(row.index), appActions: actions, visualParent: row });
            m.show();
        });
    }
    Component { id: taskMenuComponent; TaskMenu {} }

    // right-click on a search result or an app in the list: pin, the match's actions, then the app's own
    function openAppMenu(visualParent, launcher, kickerActions, triggerKicker, runnerActions, runRunnerAction) {
        const items = [];
        if (launcher) items.push({ text: isPinned(launcher) ? i18n("Unpin from Rail") : i18n("Pin to Rail"),
                                   icon: isPinned(launcher) ? "window-unpin" : "window-pin", run: () => togglePin(launcher) });
        (runnerActions || []).forEach((a, i) => items.push({ text: a.text, icon: a.iconSource || "", run: () => runRunnerAction(i) }));
        for (const a of (kickerActions || [])) {
            if (a.type === "separator") { items.push({ separator: true }); continue; }
            if (a.type === "title") { items.push({ separator: true }); items.push({ text: a.text, section: true }); continue; }
            items.push({ text: a.text, icon: a.icon || "", run: () => triggerKicker(a) });
        }
        // no leading, trailing or doubled separators
        const clean = items.filter((it, i, all) => !(it.separator && (i === 0 || i === all.length - 1 || all[i + 1].separator || all[i + 1].section && i === 0)));
        if (!clean.length) return;
        const m = actionMenuComponent.createObject(root, { visualParent: visualParent });
        m.fill(clean);
        m.openRelative();
    }
    Component {
        id: actionMenuComponent
        PlasmaExtras.Menu {
            id: am
            placement: PlasmaExtras.Menu.RightPosedTopAlignedPopup
            onStatusChanged: if (status === PlasmaExtras.Menu.Closed) am.destroy()
            function fill(items) {
                for (const it of items) {
                    const mi = Qt.createQmlObject(`import org.kde.plasma.extras as PlasmaExtras
                        PlasmaExtras.MenuItem {}`, am);
                    if (it.separator) mi.separator = true;
                    else if (it.section) { mi.section = true; mi.text = it.text; }
                    else {
                        mi.text = it.text;
                        mi.icon = it.icon;
                        mi.clicked.connect(it.run);
                    }
                    am.addMenuItem(mi);
                }
            }
        }
    }

    // ---- session
    Sessions.SessionManagement { id: session }
    KCoreAddons.KUser { id: kuser }
    Kicker.SimpleFavoritesModel { id: settingsApp; favorites: ["systemsettings.desktop"] }

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

    component SectionLabel: Text {
        leftPadding: 10; topPadding: 12; bottomPadding: 4
        color: Kirigami.Theme.textColor; opacity: 0.6
        font.pixelSize: 12; font.weight: Font.Bold
        elide: Text.ElideRight
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
                    field.text = "";
                    results.currentIndex = 0;
                    if (Plasmoid.configuration.showAllApps && allApps.count === 0) allApps.refresh();
                    field.forceActiveFocus();
                    idle.contentY = 0;
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Kirigami.SearchField {
                id: field
                Layout.fillWidth: true
                Layout.bottomMargin: 6
                placeholderText: i18n("Search")
                autoAccept: false
                onTextChanged: { root.text = text; results.currentIndex = 0; }
                Keys.onDownPressed: results.incrementCurrentIndex()
                Keys.onUpPressed: results.decrementCurrentIndex()
                onAccepted: results.runCurrent()
            }

            // ---- searching: KRunner results, grouped under their category
            ListView {
                id: results
                visible: drawer.searching
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                model: search
                spacing: 2
                section.property: "category"
                section.criteria: ViewSection.FullString
                section.delegate: SectionLabel {
                    required property string section
                    width: ListView.view.width
                    text: section
                }
                function runCurrent() {
                    if (count === 0) return;
                    if (search.run(search.index(Math.max(0, currentIndex), 0))) root.open = false;
                }
                function runAction(row, i) {
                    if (search.runAction(search.index(row, 0), i)) root.open = false;
                }
                delegate: Item {
                    id: res
                    required property int index
                    required property var model
                    readonly property var urls: model.urls || []
                    readonly property string launcher: urls.length && urls[0].toString().endsWith(".desktop") ? root.launcherFor(urls[0]) : ""
                    width: ListView.view.width
                    height: 44
                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Kirigami.Theme.textColor
                        opacity: rh.hovered ? 0.1 : res.ListView.isCurrentItem ? 0.07 : 0
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 6
                        spacing: 12
                        Kirigami.Icon { source: res.model.decoration; Layout.preferredWidth: 24; Layout.preferredHeight: 24 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: res.model.display || ""; elide: Text.ElideRight
                                textFormat: res.model.multiLine ? Text.StyledText : Text.PlainText
                                color: Kirigami.Theme.textColor; font.pixelSize: 14
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: res.model.subtext || ""; elide: Text.ElideRight
                                color: Kirigami.Theme.textColor; opacity: 0.6; font.pixelSize: 11
                            }
                        }
                        Repeater { // the match's own actions, as KRunner shows them
                            model: rh.hovered || res.ListView.isCurrentItem ? res.model.actions || [] : []
                            delegate: Item {
                                id: act
                                required property var modelData
                                required property int index
                                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                                Rectangle { anchors.fill: parent; radius: 8; color: Kirigami.Theme.textColor; opacity: ab.hovered ? 0.12 : 0 }
                                Kirigami.Icon { anchors.centerIn: parent; width: 16; height: 16; source: act.modelData.iconSource || "" }
                                HoverHandler { id: ab }
                                TapHandler { onTapped: results.runAction(res.index, act.index) }
                                PlasmaCore.ToolTipArea { anchors.fill: parent; mainText: act.modelData.text || "" }
                            }
                        }
                    }
                    HoverHandler { id: rh }
                    TapHandler {
                        onTapped: if (search.run(search.index(res.index, 0))) root.open = false
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onClicked: {
                            const actions = res.model.actions || [];
                            const run = i => results.runAction(res.index, i);
                            if (res.launcher) {
                                const file = res.urls[0].toString();
                                root.withAppActions(file.substring(file.lastIndexOf("/") + 1),
                                    k => root.openAppMenu(res, res.launcher, k, root.triggerAppAction, actions, run));
                            } else root.openAppMenu(res, "", [], null, actions, run);
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: results.count === 0 && !search.querying
                    text: i18n("No results")
                    color: Kirigami.Theme.textColor; opacity: 0.6; font.pixelSize: 13
                }
            }

            // ---- idle: running, pinned, all apps
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
                        visible: Plasmoid.configuration.showRunning && runningCount.n > 0
                        spacing: 2
                        SectionLabel { text: i18n("Running"); topPadding: 6 }
                        Repeater {
                            model: appModel
                            delegate: AppRow { run: true }
                        }
                    }
                    Column {
                        Layout.fillWidth: true
                        Layout.row: Plasmoid.configuration.runningFirst ? 1 : 0
                        visible: Plasmoid.configuration.showPinned && pinnedCount.n > 0
                        spacing: 2
                        SectionLabel { text: i18n("Pinned") }
                        Repeater {
                            model: appModel
                            delegate: AppRow { run: false }
                        }
                    }
                    // every installed app, under its menu category
                    Column {
                        Layout.fillWidth: true
                        Layout.row: 2
                        visible: Plasmoid.configuration.showAllApps
                        spacing: 2
                        Repeater {
                            model: Plasmoid.configuration.showAllApps ? allApps : null
                            delegate: Column {
                                id: cat
                                required property int index
                                required property var model
                                readonly property var apps: allApps.modelForRow(index)
                                width: parent ? parent.width : 0
                                spacing: 2
                                visible: apps !== null && apps.count > 0
                                SectionLabel { text: cat.model.display || ""; width: parent.width }
                                Repeater {
                                    model: cat.apps
                                    delegate: Item {
                                        id: app
                                        required property int index
                                        required property var model
                                        readonly property string launcher: model.favoriteId ? "applications:" + model.favoriteId.replace(/^applications:/, "") : ""
                                        width: cat.width
                                        height: 40
                                        Rectangle { anchors.fill: parent; radius: 12; color: Kirigami.Theme.textColor; opacity: apph.hovered ? 0.1 : 0 }
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10; anchors.rightMargin: 10
                                            spacing: 12
                                            Kirigami.Icon { source: app.model.decoration; Layout.preferredWidth: Plasmoid.configuration.iconSize; Layout.preferredHeight: Plasmoid.configuration.iconSize }
                                            Text {
                                                Layout.fillWidth: true
                                                text: app.model.display || ""
                                                elide: Text.ElideRight
                                                color: Kirigami.Theme.textColor
                                                font.pixelSize: 14
                                            }
                                        }
                                        HoverHandler { id: apph }
                                        TapHandler { onTapped: { cat.apps.trigger(app.index, "", null); root.open = false; } }
                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.RightButton
                                            onClicked: root.openAppMenu(app, app.launcher, app.model.actionList || [],
                                                a => { cat.apps.trigger(app.index, a.actionId, a.actionArgument); root.open = false; })
                                        }
                                    }
                                }
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
                        visible: avatar.status !== Image.Ready
                        text: kuser.loginName.length ? kuser.loginName[0].toUpperCase() : ""
                        color: Kirigami.Theme.highlightedTextColor
                        font.pixelSize: 15; font.weight: Font.Bold
                    }
                    Kirigami.ShadowedImage {
                        id: avatar
                        anchors.fill: parent
                        radius: 16
                        source: kuser.faceIconUrl
                        visible: status === Image.Ready
                    }
                }
                Item { Layout.fillWidth: true; visible: !Plasmoid.configuration.showUserName }
                Text {
                    Layout.fillWidth: true
                    visible: Plasmoid.configuration.showUserName
                    text: kuser.fullName || kuser.loginName
                    elide: Text.ElideRight
                    color: Kirigami.Theme.textColor
                    font.pixelSize: 14; font.weight: Font.DemiBold
                }
                Repeater {
                    model: [
                        { icon: "preferences-system-symbolic", tip: i18n("System Settings"), act: "settings", on: Plasmoid.configuration.showSettingsButton },
                        { icon: "system-lock-screen-symbolic", tip: i18n("Lock"), act: "lock", on: Plasmoid.configuration.showLockButton && session.canLock },
                        { icon: "system-shutdown-symbolic", tip: i18n("Shut Down…"), act: "power", on: Plasmoid.configuration.showPowerButton && session.canShutdown }
                    ].filter(b => b.on)
                    delegate: Item {
                        id: btnItem
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
                            source: btnItem.modelData.icon
                            isMask: true
                            color: Kirigami.Theme.textColor
                        }
                        HoverHandler { id: bh }
                        PlasmaCore.ToolTipArea { anchors.fill: parent; mainText: btnItem.modelData.tip }
                        TapHandler {
                            onTapped: {
                                root.open = false;
                                switch (btnItem.modelData.act) {
                                case "settings": settingsApp.trigger(0, "", null); break;
                                case "lock": session.lock(); break;
                                case "power": session.requestShutdown(); break;
                                }
                            }
                        }
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
        // TaskMenu asks about audio; the drawer does not track streams
        readonly property bool hasAudioStream: false
        readonly property bool muted: false
        function toggleMuted() {}
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
            onClicked: root.openTaskMenu(row)
        }
        TapHandler {
            onTapped: root.openApp(row.index, row.running, row.active, row.model.IsGroupParent === true)
        }
    }
}
