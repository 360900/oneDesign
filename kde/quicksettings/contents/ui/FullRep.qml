import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: full

    readonly property real contentHeight: pageLoader.item ? pageLoader.item.implicitHeight + pad * 2 : 0
    readonly property real pad: Kirigami.Units.smallSpacing * 2

    Layout.preferredWidth: Kirigami.Units.gridUnit * [18, 22, 30][Math.max(1, Math.min(3, root.cfg.columns)) - 1]
    Layout.minimumWidth: Layout.preferredWidth
    Layout.maximumWidth: Layout.preferredWidth
    Layout.preferredHeight: contentHeight
    Layout.minimumHeight: contentHeight
    Layout.maximumHeight: contentHeight

    Loader {
        id: pageLoader
        anchors.fill: parent
        anchors.margins: full.pad
        source: (root.page || "Main") + "Page.qml"
    }
}
