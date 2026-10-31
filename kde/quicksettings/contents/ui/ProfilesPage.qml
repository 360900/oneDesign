import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    spacing: Kirigami.Units.smallSpacing

    readonly property var power: root.power

    PageHeader { title: i18n("Power Mode") }

    Repeater {
        model: power.profileList
        ListRow {
            icon: power.profileIconFor(modelData)
            label: power.profileName(modelData)
            checked: power.profile === modelData
            onClicked: power.setProfile(modelData)
        }
    }

    ListRow {
        icon: "emblem-system-symbolic"
        label: i18n("Power Settings")
        onClicked: root.openKcm("kcm_powerdevilprofilesconfig")
    }
}
