import QtQuick
import org.kde.kirigami as Kirigami

MouseArea {
    id: sw

    property bool on: false

    implicitWidth: Kirigami.Units.gridUnit * 2.5
    implicitHeight: Kirigami.Units.gridUnit * 1.4
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.on ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.2)
        Behavior on color { ColorAnimation { duration: 160 } }
    }
    Rectangle {
        width: sw.height - 6
        height: width
        radius: width / 2
        y: 3
        x: sw.on ? sw.width - width - 3 : 3
        color: "white"
        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
}
