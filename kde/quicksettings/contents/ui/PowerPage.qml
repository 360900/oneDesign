import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    spacing: Kirigami.Units.smallSpacing

    readonly property var session: root.session

    function run(fn) {
        root.expanded = false;
        fn();
    }

    PageHeader { title: i18n("Power Off") }

    ListRow {
        visible: session.canSuspend
        icon: "media-playback-pause-symbolic"
        label: i18n("Suspend")
        onClicked: run(session.suspend)
    }
    ListRow {
        visible: session.canReboot
        icon: "system-reboot-symbolic"
        label: i18n("Restart…")
        onClicked: run(session.reboot)
    }
    ListRow {
        visible: session.canShutdown
        icon: "system-shutdown-symbolic"
        label: i18n("Power Off…")
        onClicked: run(session.shutdown)
    }
    ListRow {
        visible: session.canLogout
        icon: "system-log-out-symbolic"
        label: i18n("Log Out…")
        onClicked: run(session.logout)
    }
}
