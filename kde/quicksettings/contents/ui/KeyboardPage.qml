import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    spacing: Kirigami.Units.smallSpacing

    readonly property var keyboard: root.keyboard

    PageHeader { title: i18n("Keyboard Layout") }

    Repeater {
        model: keyboard ? keyboard.layouts : []
        ListRow {
            required property var modelData
            required property int index
            icon: "input-keyboard-symbolic"
            label: modelData.longName
            sub: modelData.shortName.toUpperCase()
            checked: keyboard.current === index
            onClicked: keyboard.select(index)
        }
    }

    ListRow {
        icon: "emblem-system-symbolic"
        label: i18n("Keyboard Settings")
        onClicked: root.openKcm("kcm_keyboard")
    }
}
