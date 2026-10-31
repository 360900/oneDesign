import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: tile

    property string icon
    property string label
    property string sub
    property bool on: false
    property bool hasMore: false
    property bool shown: true
    property bool compact: !!root.cfg.compactTiles

    signal toggled()
    signal more()

    readonly property color fg: on ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor

    Layout.fillWidth: true
    implicitHeight: Kirigami.Units.gridUnit * (compact ? 2.4 : 3.1)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: tile.on ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.08)
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    MouseArea {
        id: mainArea
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: tile.hasMore ? moreArea.left : parent.right }
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.toggled()

        Rectangle {
            anchors.fill: parent
            color: tile.fg
            opacity: mainArea.pressed ? 0.12 : mainArea.containsMouse ? 0.06 : 0
            topLeftRadius: tile.height / 2
            bottomLeftRadius: tile.height / 2
            topRightRadius: tile.hasMore ? 0 : tile.height / 2
            bottomRightRadius: tile.hasMore ? 0 : tile.height / 2
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.gridUnit * 0.85
            anchors.rightMargin: Kirigami.Units.smallSpacing * 2
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                source: tile.icon
                isMask: true
                color: tile.fg
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: tile.label
                    color: tile.fg
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0 && !tile.compact
                    text: tile.sub
                    color: tile.fg
                    opacity: 0.75
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    elide: Text.ElideRight
                }
            }
        }
    }

    MouseArea {
        id: moreArea
        visible: tile.hasMore
        width: tile.hasMore ? Kirigami.Units.gridUnit * 2.4 : 0
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.more()

        Rectangle {
            anchors.fill: parent
            color: tile.fg
            opacity: moreArea.pressed ? 0.12 : moreArea.containsMouse ? 0.06 : 0
            topRightRadius: tile.height / 2
            bottomRightRadius: tile.height / 2
        }
        Rectangle {
            width: 1
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            height: parent.height * 0.5
            color: tile.fg
            opacity: 0.18
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -2
            width: Kirigami.Units.iconSizes.small
            height: width
            source: "go-next-symbolic"
            isMask: true
            color: tile.fg
        }
    }
}
