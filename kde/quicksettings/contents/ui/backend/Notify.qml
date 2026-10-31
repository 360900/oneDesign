import QtQuick
import org.kde.notificationmanager as NotificationManager

Item {
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

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: parent.now = new Date()
    }
}
