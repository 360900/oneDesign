import QtQuick
import org.kde.pipewire.monitor as Monitor

Item {
    readonly property bool inUse: monitor.detectionAvailable && monitor.runningCount > 0
    readonly property int count: monitor.runningCount

    Monitor.MediaMonitor {
        id: monitor
        role: Monitor.MediaRole.Camera
    }
}
