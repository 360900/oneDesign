import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: header

    property string title
    property bool hasToggle: false
    property bool on: false

    signal toggled()

    Layout.fillWidth: true
    Layout.bottomMargin: Kirigami.Units.smallSpacing
    spacing: Kirigami.Units.largeSpacing

    IconBtn {
        icon: "go-previous-symbolic"
        onClicked: root.page = ""
    }
    Text {
        Layout.fillWidth: true
        text: header.title
        color: Kirigami.Theme.textColor
        font.weight: Font.Bold
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
        elide: Text.ElideRight
    }
    Toggle {
        visible: header.hasToggle
        on: header.on
        onClicked: header.toggled()
    }
}
