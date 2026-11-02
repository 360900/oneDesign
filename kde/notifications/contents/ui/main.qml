import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager

// A round bell with an unread badge. Click: history. Middle click: Do Not Disturb.
PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    hideOnWindowDeactivate: true
    toolTipMainText: i18n("Notifications")
    toolTipSubText: dnd ? i18n("Do Not Disturb is on") : unread > 0 ? i18np("%1 unread", "%1 unread", unread) : i18n("No new notifications")

    readonly property bool dark: Kirigami.Theme.textColor.hsvValue > 0.5
    readonly property color fill: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.55)
    readonly property color fillHover: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0.2, 0.28, 0.4, 0.2)
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color fillPressed: Qt.tint(fillHover, Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.45 : 0.30))
    readonly property int unread: history.unreadNotificationsCount
    property date now: new Date()
    readonly property bool dnd: {
        const until = settings.notificationsInhibitedUntil;
        return !!until && !isNaN(until.getTime()) && now.getTime() < until.getTime();
    }

    function setDnd(on) {
        if (on) {
            // "In a year" is the notifications applet's convention for "until turned off"
            const d = new Date();
            d.setFullYear(d.getFullYear() + 1);
            settings.notificationsInhibitedUntil = d;
        } else {
            settings.notificationsInhibitedUntil = undefined;
            settings.revokeApplicationInhibitions();
        }
        settings.save();
        now = new Date();
    }

    NotificationManager.Settings { id: settings }
    Timer { interval: 60000; repeat: true; running: true; onTriggered: root.now = new Date() }

    NotificationManager.Notifications {
        id: history
        showExpired: true
        showDismissed: true
        showJobs: false
        showAddedDuringInhibition: true
        groupMode: NotificationManager.Notifications.GroupDisabled
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        limit: 60
        lastRead: new Date()
    }

    Connections {
        target: root
        function onExpandedChanged() {
            if (root.expanded) history.lastRead = new Date();
        }
    }

    function ago(date) {
        const s = Math.max(0, (new Date() - date) / 1000);
        if (s < 60) return i18n("now");
        if (s < 3600) return i18n("%1 min", Math.round(s / 60));
        if (s < 86400) return i18n("%1 h", Math.round(s / 3600));
        return Qt.formatDate(date, "d MMM");
    }

    compactRepresentation: MouseArea {
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
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) root.setDnd(!root.dnd);
            else root.expanded = !root.expanded;
        }

        Rectangle {
            anchors.centerIn: parent
            width: 44; height: 44
            radius: btn.vertical ? 12 : 22
            color: root.expanded || btn.pressed ? root.fillPressed : btn.containsMouse ? root.fillHover : root.fill
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, root.dark ? 0.12 : 0.6)
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: 22; height: 22
            source: root.dnd ? "notifications-disabled-symbolic" : "notifications-symbolic"
            isMask: true
            color: Kirigami.Theme.textColor
        }
        Rectangle { // unread badge
            visible: root.unread > 0 && !root.dnd
            x: parent.width / 2 + 8; y: parent.height / 2 - 22
            width: Math.max(16, badge.implicitWidth + 8); height: 16
            radius: 8
            color: root.accent
            border.width: 1.5
            border.color: Qt.rgba(1, 1, 1, 0.55)
            Text {
                id: badge
                anchors.centerIn: parent
                text: root.unread > 9 ? "9+" : root.unread
                color: Kirigami.Theme.highlightedTextColor
                font.pixelSize: 10; font.weight: Font.Bold
            }
        }
    }

    fullRepresentation: Item {
        id: pop
        Layout.minimumWidth: 380
        Layout.preferredWidth: 380
        Layout.minimumHeight: 200
        Layout.preferredHeight: Math.min(620, Math.max(260, Screen.height * 0.6))
        Keys.onEscapePressed: root.expanded = false

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                spacing: 8
                Text {
                    text: i18n("Notifications")
                    Layout.fillWidth: true
                    color: Kirigami.Theme.textColor
                    font.pixelSize: 16; font.weight: Font.Bold
                }
                // Do Not Disturb
                Rectangle {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: dndRow.implicitWidth + 20
                    radius: 14
                    color: root.dnd ? root.accent : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, dh.hovered ? 0.14 : 0.08)
                    RowLayout {
                        id: dndRow
                        anchors.centerIn: parent
                        spacing: 6
                        Kirigami.Icon {
                            Layout.preferredWidth: 14; Layout.preferredHeight: 14
                            source: "notifications-disabled-symbolic"
                            isMask: true
                            color: root.dnd ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                        }
                        Text {
                            text: i18n("Do Not Disturb")
                            color: root.dnd ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                            font.pixelSize: 12; font.weight: Font.DemiBold
                        }
                    }
                    HoverHandler { id: dh }
                    TapHandler { onTapped: root.setDnd(!root.dnd) }
                }
                Rectangle {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: clearText.implicitWidth + 20
                    radius: 14
                    visible: list.count > 0
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, ch.hovered ? 0.14 : 0.08)
                    Text {
                        id: clearText
                        anchors.centerIn: parent
                        text: i18n("Clear")
                        color: Kirigami.Theme.textColor
                        font.pixelSize: 12; font.weight: Font.DemiBold
                    }
                    HoverHandler { id: ch }
                    TapHandler { onTapped: history.clear(NotificationManager.Notifications.ClearExpired) }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                model: history

                delegate: Item {
                    id: card
                    required property int index
                    required property var model
                    width: ListView.view.width
                    height: Math.max(60, content.implicitHeight + 20)

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, ph.hovered ? 0.1 : 0.06)
                    }
                    RowLayout {
                        id: content
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10
                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 32; Layout.preferredHeight: 32
                            source: card.model.applicationIconName || card.model.iconName || "dialog-information"
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: card.model.applicationName || ""
                                    elide: Text.ElideRight
                                    color: Kirigami.Theme.textColor; opacity: 0.6
                                    font.pixelSize: 11
                                }
                                Text {
                                    text: card.model.created ? root.ago(card.model.created) : ""
                                    color: Kirigami.Theme.textColor; opacity: 0.6
                                    font.pixelSize: 11
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: card.model.summary || ""
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                color: Kirigami.Theme.textColor
                                font.pixelSize: 13; font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: (card.model.body || "").replace(/<[^>]*>/g, "")
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                color: Kirigami.Theme.textColor; opacity: 0.85
                                font.pixelSize: 12
                            }
                        }
                        Item { // dismiss
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 22; Layout.preferredHeight: 22
                            visible: card.model.closable === true
                            opacity: ph.hovered ? 1 : 0
                            Rectangle {
                                anchors.fill: parent; radius: 11
                                color: Kirigami.Theme.textColor; opacity: xh.hovered ? 0.18 : 0.08
                            }
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 10; height: 10
                                source: "window-close-symbolic"; isMask: true; color: Kirigami.Theme.textColor
                            }
                            HoverHandler { id: xh }
                            TapHandler { onTapped: history.close(history.index(card.index, 0)) }
                        }
                    }
                    HoverHandler { id: ph }
                    TapHandler {
                        onTapped: if (card.model.hasDefaultAction) {
                            history.invokeDefaultAction(history.index(card.index, 0), NotificationManager.Notifications.Close);
                            root.expanded = false;
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    spacing: 10
                    Kirigami.Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 40; height: 40
                        source: "notifications-symbolic"; isMask: true; color: Kirigami.Theme.textColor; opacity: 0.35
                    }
                    Text {
                        text: i18n("No notifications")
                        color: Kirigami.Theme.textColor; opacity: 0.6
                        font.pixelSize: 14
                    }
                }
            }
        }
    }
}
