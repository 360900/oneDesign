import QtQuick
import org.kde.plasma.private.sessions

Item {
    readonly property alias canLock: sm.canLock
    readonly property alias canSuspend: sm.canSuspend
    readonly property alias canReboot: sm.canReboot
    readonly property alias canShutdown: sm.canShutdown
    readonly property alias canLogout: sm.canLogout

    function lock() { sm.lock(); }
    function suspend() { sm.suspend(); }
    function reboot() { sm.requestReboot(); }
    function shutdown() { sm.requestShutdown(); }
    function logout() { sm.requestLogout(); }

    SessionManagement { id: sm }
}
