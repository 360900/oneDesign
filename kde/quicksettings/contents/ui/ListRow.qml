import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

MouseArea {
    id: item

    property string icon
    property string label
    property string sub
    property bool checked: false
    property bool busy: false
    property real trailing: 0

    Layout.fillWidth: true
    implicitWidth: Kirigami.Units.gridUnit * 18
    implicitHeight: Kirigami.Units.gridUnit * 2.6
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius + 4
        color: Kirigami.Theme.textColor
        opacity: item.pressed ? 0.12 : item.containsMouse ? 0.07 : 0
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing + item.trailing
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Icon {
            visible: item.icon.length > 0
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: item.icon
            isMask: true
            color: Kirigami.Theme.textColor
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: item.label
                color: Kirigami.Theme.textColor
                font.weight: item.checked ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: item.sub
                color: Kirigami.Theme.textColor
                opacity: 0.6
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
            }
        }
        Kirigami.Icon {
            visible: item.checked && !item.busy
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: "object-select-symbolic"
            isMask: true
            color: Kirigami.Theme.highlightColor
        }
        Rectangle {
            visible: item.busy
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Kirigami.Theme.highlightColor
            Rectangle {
                width: 6; height: 6; radius: 3
                color: Kirigami.Theme.backgroundColor
                x: parent.width - 5; y: parent.height / 2 - 3
            }
            RotationAnimation on rotation { running: item.busy; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
        }
    }
}
