import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

// 15 over 42, bold, with the date underneath: the rail's clock.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    toolTipMainText: Qt.formatDateTime(now, "dddd, d MMMM yyyy")
    toolTipSubText: Qt.formatTime(now, "HH:mm:ss")

    property date now: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    fullRepresentation: Item {
        Layout.fillWidth: true
        Layout.minimumHeight: col.implicitHeight + 10
        Layout.preferredHeight: col.implicitHeight + 10
        Column {
            id: col
            anchors.centerIn: parent
            spacing: 0
            Repeater {
                model: [Qt.formatTime(root.now, "HH"), Qt.formatTime(root.now, "mm")]
                Text {
                    required property string modelData
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData
                    color: Kirigami.Theme.textColor
                    font.pixelSize: 17
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                    lineHeight: 0.92
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 4
                text: Qt.formatDate(root.now, "d MMM")
                color: Kirigami.Theme.textColor
                opacity: 0.65
                font.pixelSize: 11
            }
        }
    }
}
