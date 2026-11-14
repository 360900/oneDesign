/*
    What a dragged window looks like under the pointer: its icon and title on a floating card.
    Kept out of view and grabbed into an image before a drag starts, since a drag image has to be
    ready when the drag begins.
*/
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: card

    property var icon
    property string title
    // room around the card for its shadow, inside the grabbed image
    readonly property int pad: 16
    property url image

    width: surface.width + pad * 2
    height: surface.height + pad * 2

    // grabs the card as it is now; the image is ready a frame later
    function refresh() {
        grabToImage(result => { card.image = result.url; });
    }

    Kirigami.ShadowedRectangle {
        id: surface
        x: card.pad; y: card.pad
        width: Math.min(240, row.implicitWidth + 24)
        height: 44
        radius: 14
        color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.97)
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.14)
        shadow.size: 14
        shadow.yOffset: 4
        shadow.color: Qt.rgba(0, 0, 0, 0.28)

        Row {
            id: row
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Kirigami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24
                source: card.icon
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 240 - 24 - 24 - 8)
                text: card.title
                elide: Text.ElideRight
                color: Kirigami.Theme.textColor
                font: Kirigami.Theme.defaultFont
            }
        }
    }
}
