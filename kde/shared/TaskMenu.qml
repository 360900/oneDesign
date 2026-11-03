/*
    Task context menu. Port of KDE's task manager menu (plasma-desktop applets/taskmanager/qml/ContextMenu.qml);
    jump list and recent files come from Kicker's app entry instead of the task manager's private backend.
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.taskmanager as TaskManager
import org.kde.plasma.private.mpris as Mpris

PlasmaExtras.Menu {
    id: menu

    required property var r            // the rail root: models and helpers
    required property var modelIndex
    required property var appActions    // Kicker action list of the app (jump list, recent files)
    readonly property var tasksModel: r.tasksModel
    readonly property var vdi: r.virtualDesktopInfo
    readonly property var activityInfo: r.activityInfo

    placement: Plasmoid.location === PlasmaCore.Types.RightEdge ? PlasmaExtras.Menu.LeftPosedTopAlignedPopup
             : PlasmaExtras.Menu.RightPosedTopAlignedPopup

    onStatusChanged: if (status === PlasmaExtras.Menu.Closed) menu.destroy()

    function get(role) { return tasksModel.data(modelIndex, role); }

    function show() {
        loadDynamicActions();
        openRelative();
    }

    function newMenuItem(parent) {
        return Qt.createQmlObject(`import org.kde.plasma.extras as PlasmaExtras
            PlasmaExtras.MenuItem {}`, parent);
    }
    function newSeparator(parent) {
        return Qt.createQmlObject(`import org.kde.plasma.extras as PlasmaExtras
            PlasmaExtras.MenuItem { separator: true }`, parent);
    }

    function loadDynamicActions() {
        // Kicker lists recent files under a title, then jump list actions; app management entries are left out
        const recents = [], actions = [];
        let inRecents = false;
        for (const a of (appActions || [])) {
            if (a.type === "title") { inRecents = true; continue; }
            if (a.type === "separator") { inRecents = false; continue; }
            if (a.actionId === "editApplication" || a.actionId === "manageApplication") continue;
            (inRecents || a.actionId === "_kicker_recentDocument" || a.actionId === "_kicker_forgetRecentDocuments" ? recents : actions).push(a);
        }
        const sections = [];
        if (recents.length) sections.push({ title: i18nc("@title:group for section of menu items", "Recent Files"), actions: recents });
        sections.push({ title: i18nc("@title:group for section of menu items", "Actions"), actions: actions, group: "actions" });

        const metrics = Qt.createQmlObject("import QtQuick; TextMetrics {}", menu);
        metrics.elide = Qt.ElideRight;
        metrics.elideWidth = 24 * 18;

        for (const section of sections) {
            if (!section.actions.length) continue;
            if (section.group !== "actions" || sections.length > 1) {
                const header = newMenuItem(menu);
                header.text = section.title;
                header.section = true;
                menu.addMenuItem(header, startNewInstanceItem);
            }
            for (const a of section.actions) {
                const item = newMenuItem(menu);
                metrics.text = a.text.replace("&", "&&");
                item.text = metrics.elidedText;
                item.icon = a.icon || "";
                item.clicked.connect(() => r.triggerAppAction(a));
                menu.addMenuItem(item, startNewInstanceItem);
            }
        }

        // Media player controls
        const player = r.mpris2Source.playerForLauncherUrl(get(TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon),
                                                           get(TaskManager.AbstractTasksModel.AppPid));
        const winIds = get(TaskManager.AbstractTasksModel.WinIdList);
        if (player && player.canControl && !(winIds !== undefined && winIds.length > 1)) {
            const playing = player.playbackStatus === Mpris.PlaybackStatus.Playing;
            let item = newMenuItem(menu);
            item.text = i18nc("Play previous track", "Previous Track");
            item.icon = "media-skip-backward";
            item.enabled = Qt.binding(() => player.canGoPrevious);
            item.clicked.connect(() => player.Previous());
            menu.addMenuItem(item, startNewInstanceItem);

            item = newMenuItem(menu);
            item.text = Qt.binding(() => playing && player.canPause ? i18nc("Pause playback", "Pause") : i18nc("Start playback", "Play"));
            item.icon = Qt.binding(() => playing && player.canPause ? "media-playback-pause" : "media-playback-start");
            item.enabled = Qt.binding(() => playing ? player.canPause : player.canPlay);
            item.clicked.connect(() => playing ? player.Pause() : player.Play());
            menu.addMenuItem(item, startNewInstanceItem);

            item = newMenuItem(menu);
            item.text = i18nc("Play next track", "Next Track");
            item.icon = "media-skip-forward";
            item.enabled = Qt.binding(() => player.canGoNext);
            item.clicked.connect(() => player.Next());
            menu.addMenuItem(item, startNewInstanceItem);

            item = newMenuItem(menu);
            item.text = i18nc("Stop playback", "Stop");
            item.icon = "media-playback-stop";
            item.enabled = Qt.binding(() => player.canStop);
            item.clicked.connect(() => player.Stop());
            menu.addMenuItem(item, startNewInstanceItem);

            if (!menu.visualParent.hasAudioStream) menu.addMenuItem(newSeparator(menu), startNewInstanceItem);

            if (!closeWindowItem.visible && player.canQuit) {
                item = newMenuItem(menu);
                item.text = i18nc("Quit media player app", "Quit");
                item.icon = "application-exit";
                item.clicked.connect(() => player.Quit());
                menu.addMenuItem(item);
            }
            if (get(TaskManager.AbstractTasksModel.IsLauncher) && !startNewInstanceItem.visible && player.canRaise) {
                item = newMenuItem(menu);
                item.text = i18nc("Open or bring to the front window of media player app", "Restore");
                item.icon = player.iconName;
                item.clicked.connect(() => player.Raise());
                menu.addMenuItem(item, startNewInstanceItem);
            }
        }

        // Mute, whenever the app has a stream, playing or not
        if (menu.visualParent.hasAudioStream) {
            const mute = newMenuItem(menu);
            mute.checkable = true;
            mute.checked = Qt.binding(() => menu.visualParent && menu.visualParent.muted);
            mute.clicked.connect(() => menu.visualParent.toggleMuted());
            mute.text = i18nc("@option:check inmenu, no separate unmute action", "Mute");
            mute.icon = "audio-volume-muted";
            menu.addMenuItem(mute, startNewInstanceItem);
            menu.addMenuItem(newSeparator(menu), startNewInstanceItem);
        }
    }

    PlasmaExtras.MenuItem {
        id: startNewInstanceItem
        visible: menu.get(TaskManager.AbstractTasksModel.CanLaunchNewInstance)
        text: i18nc("action:inmenu", "Open New Window")
        icon: "window-new"
        onClicked: menu.tasksModel.requestNewInstance(menu.modelIndex)
    }

    PlasmaExtras.MenuItem {
        id: virtualDesktopsMenuItem
        visible: menu.vdi.numberOfDesktops > 1
            && !menu.get(TaskManager.AbstractTasksModel.IsLauncher)
            && !menu.get(TaskManager.AbstractTasksModel.IsStartup)
            && menu.get(TaskManager.AbstractTasksModel.IsVirtualDesktopsChangeable)
        enabled: visible
        text: i18nc("action:inmenu", "Move to &Desktop")
        icon: "virtual-desktops"

        readonly property PlasmaExtras.Menu _desktops: PlasmaExtras.Menu {
            id: desktopsMenu
            visualParent: virtualDesktopsMenuItem.action

            function refresh() {
                clearMenuItems();
                if (menu.vdi.numberOfDesktops <= 1 || !virtualDesktopsMenuItem.enabled) return;

                let item = menu.newMenuItem(desktopsMenu);
                item.text = i18nc("action:inmenu", "Move &To Current Desktop");
                item.enabled = Qt.binding(() => {
                    let off = false;
                    menu.r.foreachChildTask(idx => {
                        off = off || menu.tasksModel.data(idx, TaskManager.AbstractTasksModel.VirtualDesktops).indexOf(menu.vdi.currentDesktop) === -1;
                    }, menu.modelIndex);
                    return off;
                });
                item.clicked.connect(() => menu.r.foreachChildTask(idx => menu.tasksModel.requestVirtualDesktops(idx, [menu.vdi.currentDesktop]), menu.modelIndex));

                item = menu.newMenuItem(desktopsMenu);
                item.text = i18nc("action:inmenu", "&All Desktops");
                item.checkable = true;
                item.checked = Qt.binding(() => menu.get(TaskManager.AbstractTasksModel.IsOnAllVirtualDesktops) === true);
                item.clicked.connect(() => menu.tasksModel.requestVirtualDesktops(menu.modelIndex, []));

                menu.newSeparator(desktopsMenu);

                for (let i = 0; i < menu.vdi.desktopNames.length; ++i) {
                    item = menu.newMenuItem(desktopsMenu);
                    item.text = menu.vdi.desktopNames[i];
                    item.checkable = true;
                    item.checked = Qt.binding((i => () => (menu.get(TaskManager.AbstractTasksModel.VirtualDesktops) || []).indexOf(menu.vdi.desktopIds[i]) > -1)(i));
                    item.clicked.connect((i => () => menu.tasksModel.requestVirtualDesktops(menu.modelIndex, [menu.vdi.desktopIds[i]]))(i));
                }

                menu.newSeparator(desktopsMenu);

                item = menu.newMenuItem(desktopsMenu);
                item.text = i18nc("action:inmenu", "&New Desktop");
                item.icon = "list-add";
                item.clicked.connect(() => menu.tasksModel.requestNewVirtualDesktop(menu.modelIndex));
            }
            Component.onCompleted: refresh()
        }
    }

    PlasmaExtras.MenuItem {
        id: activitiesMenuItem
        visible: menu.activityInfo.numberOfRunningActivities > 1
            && !menu.get(TaskManager.AbstractTasksModel.IsLauncher)
            && !menu.get(TaskManager.AbstractTasksModel.IsStartup)
        enabled: visible
        text: i18nc("action:inmenu", "Show in &Activities")
        icon: "activities"

        readonly property PlasmaExtras.Menu _activities: PlasmaExtras.Menu {
            id: activitiesMenu
            visualParent: activitiesMenuItem.action

            function refresh() {
                clearMenuItems();
                if (menu.activityInfo.numberOfRunningActivities <= 1) return;
                const A = TaskManager.AbstractTasksModel.Activities;

                let item = menu.newMenuItem(activitiesMenu);
                item.text = i18nc("action:inmenu", "Add To Current Activity");
                item.enabled = Qt.binding(() => menu.get(A).length > 0 && menu.get(A).indexOf(menu.activityInfo.currentActivity) < 0);
                item.clicked.connect(() => menu.tasksModel.requestActivities(menu.modelIndex, menu.get(A).concat(menu.activityInfo.currentActivity)));

                item = menu.newMenuItem(activitiesMenu);
                item.text = i18nc("action:inmenu", "All Activities");
                item.checkable = true;
                item.checked = Qt.binding(() => menu.get(A).length === 0);
                item.toggled.connect(checked => menu.tasksModel.requestActivities(menu.modelIndex, checked ? [] : [menu.activityInfo.currentActivity]));

                menu.newSeparator(activitiesMenu);

                const running = menu.activityInfo.runningActivities();
                for (const id of running) {
                    item = menu.newMenuItem(activitiesMenu);
                    item.text = menu.activityInfo.activityName(id);
                    item.icon = menu.activityInfo.activityIcon(id);
                    item.checkable = true;
                    item.checked = Qt.binding((id => () => menu.get(A).indexOf(id) >= 0)(id));
                    item.toggled.connect((id => checked => {
                        let list = menu.get(A);
                        if (checked) list = list.concat(id);
                        else { const i = list.indexOf(id); if (i < 0) return; list.splice(i, 1); }
                        menu.tasksModel.requestActivities(menu.modelIndex, list);
                    })(id));
                }

                menu.newSeparator(activitiesMenu);

                for (const id of running) {
                    const on = menu.get(A);
                    if (on.length === 1 && on[0] === id) continue;
                    item = menu.newMenuItem(activitiesMenu);
                    item.text = i18nc("action:inmenu", "Move to %1", menu.activityInfo.activityName(id));
                    item.icon = menu.activityInfo.activityIcon(id);
                    item.clicked.connect((id => () => menu.tasksModel.requestActivities(menu.modelIndex, [id]))(id));
                }
            }
            Component.onCompleted: refresh()
        }
    }

    PlasmaExtras.MenuItem {
        id: pinItem
        readonly property url launcher: menu.get(TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon)
        readonly property bool pinned: menu.tasksModel.launcherPosition(launcher) >= 0
        visible: !menu.get(TaskManager.AbstractTasksModel.IsStartup) && Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
        enabled: launcher.toString() !== ""
        text: pinned ? menu.r.unpinText : menu.r.pinText
        icon: pinned ? "window-unpin" : "window-pin"
        onClicked: pinned ? menu.tasksModel.requestRemoveLauncher(launcher)
                          : menu.tasksModel.requestAddLauncher(menu.get(TaskManager.AbstractTasksModel.LauncherUrl))
    }

    PlasmaExtras.MenuItem {
        id: moreActionsMenuItem
        visible: !menu.get(TaskManager.AbstractTasksModel.IsLauncher) && !menu.get(TaskManager.AbstractTasksModel.IsStartup)
        enabled: visible
        text: i18nc("item:inmenu opens submenu", "More")
        icon: "view-more-symbolic"

        readonly property PlasmaExtras.Menu moreMenu: PlasmaExtras.Menu {
            visualParent: moreActionsMenuItem.action

            PlasmaExtras.MenuItem {
                enabled: menu.get(TaskManager.AbstractTasksModel.IsMovable) === true
                text: i18nc("action:inmenu", "&Move")
                icon: "transform-move"
                onClicked: menu.tasksModel.requestMove(menu.modelIndex)
            }
            PlasmaExtras.MenuItem {
                enabled: menu.get(TaskManager.AbstractTasksModel.IsResizable) === true
                text: i18nc("action:inmenu", "Re&size")
                icon: "transform-scale"
                onClicked: menu.tasksModel.requestResize(menu.modelIndex)
            }
            PlasmaExtras.MenuItem {
                enabled: menu.get(TaskManager.AbstractTasksModel.IsMaximizable) === true
                checkable: true
                checked: menu.get(TaskManager.AbstractTasksModel.IsMaximized) === true
                text: i18nc("action:inmenu", "Ma&ximize")
                icon: "window-maximize"
                onClicked: menu.tasksModel.requestToggleMaximized(menu.modelIndex)
            }
            PlasmaExtras.MenuItem {
                enabled: menu.get(TaskManager.AbstractTasksModel.IsMinimizable) === true
                checkable: true
                checked: menu.get(TaskManager.AbstractTasksModel.IsMinimized) === true
                text: i18nc("action:inmenu", "Mi&nimize")
                icon: "window-minimize"
                onClicked: menu.tasksModel.requestToggleMinimized(menu.modelIndex)
            }
            PlasmaExtras.MenuItem {
                checkable: true
                checked: menu.get(TaskManager.AbstractTasksModel.IsKeepAbove) === true
                text: i18nc("action:inmenu", "Keep &Above Others")
                icon: "window-keep-above"
                onClicked: menu.tasksModel.requestToggleKeepAbove(menu.modelIndex)
            }
            PlasmaExtras.MenuItem {
                checkable: true
                checked: menu.get(TaskManager.AbstractTasksModel.IsKeepBelow) === true
                text: i18nc("action:inmenu", "Keep &Below Others")
                icon: "window-keep-below"
                onClicked: menu.tasksModel.requestToggleKeepBelow(menu.modelIndex)
            }
            PlasmaExtras.MenuItem {
                enabled: menu.get(TaskManager.AbstractTasksModel.IsFullScreenable) === true
                checkable: true
                checked: menu.get(TaskManager.AbstractTasksModel.IsFullScreen) === true
                text: i18nc("action:inmenu", "&Fullscreen")
                icon: "view-fullscreen"
                onClicked: menu.tasksModel.requestToggleFullScreen(menu.modelIndex)
            }
            PlasmaExtras.MenuItem {
                enabled: menu.get(TaskManager.AbstractTasksModel.CanSetNoBoder) === true
                checkable: true
                checked: menu.get(TaskManager.AbstractTasksModel.HasNoBorder) === true
                text: i18nc("@action:inmenu", "&No Titlebar and Frame")
                icon: "edit-none-border"
                onClicked: menu.tasksModel.requestToggleNoBorder(menu.modelIndex)
            }
            PlasmaExtras.MenuItem {
                checkable: true
                checked: menu.get(TaskManager.AbstractTasksModel.IsExcludedFromCapture) === true
                visible: Qt.platform.pluginName === "wayland"
                text: i18nc("@action:inmenu", "&Hide from Screencast")
                icon: "view-private"
                onClicked: menu.tasksModel.requestToggleExcludeFromCapture(menu.modelIndex)
            }
            PlasmaExtras.MenuItem { separator: true }
            PlasmaExtras.MenuItem {
                visible: Plasmoid.configuration.groupingStrategy !== 0 && menu.get(TaskManager.AbstractTasksModel.IsWindow) === true
                checkable: true
                checked: menu.get(TaskManager.AbstractTasksModel.IsGroupable) === true
                text: i18nc("@option:check inmenu", "Allow this program to be grouped")
                icon: "view-group"
                onClicked: menu.tasksModel.requestToggleGrouping(menu.modelIndex)
            }
        }
    }

    PlasmaExtras.MenuItem { separator: true }

    PlasmaExtras.MenuItem {
        property PlasmaCore.Action configureAction: null
        enabled: configureAction && configureAction.enabled
        visible: configureAction && configureAction.visible
        text: configureAction ? configureAction.text : ""
        icon: configureAction ? configureAction.icon : ""
        onClicked: configureAction.trigger()
        Component.onCompleted: configureAction = Plasmoid.internalAction("configure")
    }

    PlasmaExtras.MenuItem {
        property PlasmaCore.Action editModeAction: null
        enabled: editModeAction && editModeAction.enabled
        visible: editModeAction && editModeAction.visible
        text: editModeAction ? editModeAction.text : ""
        icon: editModeAction ? editModeAction.icon : ""
        onClicked: editModeAction.trigger()
        Component.onCompleted: editModeAction = Plasmoid.containment.internalAction("configure")
    }

    PlasmaExtras.MenuItem { separator: true }

    PlasmaExtras.MenuItem {
        id: closeWindowItem
        visible: !menu.get(TaskManager.AbstractTasksModel.IsLauncher) && !menu.get(TaskManager.AbstractTasksModel.IsStartup)
        enabled: menu.get(TaskManager.AbstractTasksModel.IsClosable) === true
        text: menu.get(TaskManager.AbstractTasksModel.IsGroupParent) ? i18nc("@action:inmenu", "&Close All") : i18nc("@action:inmenu", "&Close")
        icon: "window-close"
        onClicked: menu.tasksModel.requestClose(menu.modelIndex)
    }
}
