import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami

RowLayout {
    id: row

    property string icon
    property real value: 0
    property real to: 100
    property bool hasMore: false
    property bool iconClickable: false

    signal moved(real value)
    signal iconClicked()
    signal more()

    Layout.fillWidth: true
    spacing: Kirigami.Units.largeSpacing

    IconBtn {
        icon: row.icon
        size: Kirigami.Units.gridUnit * 2
        enabled: row.iconClickable
        onClicked: row.iconClicked()
    }

    T.Slider {
        id: slider
        Layout.fillWidth: true
        implicitHeight: Kirigami.Units.gridUnit * 1.6
        from: 0
        to: row.to
        stepSize: 1
        value: row.value
        onMoved: row.moved(value)

        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + (slider.availableHeight - height) / 2
            width: slider.availableWidth
            height: 4
            radius: 2
            color: Qt.alpha(Kirigami.Theme.textColor, 0.14)
            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: 2
                color: Kirigami.Theme.highlightColor
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + (slider.availableHeight - height) / 2
            width: Kirigami.Units.gridUnit * 1.1
            height: width
            radius: width / 2
            color: "white"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.14)
            scale: slider.pressed ? 1.1 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }
        }
    }

    IconBtn {
        visible: row.hasMore
        icon: "go-next-symbolic"
        size: Kirigami.Units.gridUnit * 2
        onClicked: row.more()
    }
}
