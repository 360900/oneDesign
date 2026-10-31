import QtQuick
import org.kde.kirigami as Kirigami

MouseArea {
    id: btn

    property string icon
    property bool on: false
    property real size: Kirigami.Units.gridUnit * 2

    implicitWidth: size
    implicitHeight: size
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: btn.on ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
        opacity: btn.on ? 1 : btn.pressed ? 0.16 : btn.containsMouse ? 0.10 : 0.06
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: Kirigami.Units.iconSizes.small
        height: width
        source: btn.icon
        isMask: true
        color: btn.on ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
    }
}
