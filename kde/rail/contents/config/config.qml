import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Layout")
        icon: "preferences-desktop-icons"
        source: "ConfigLayout.qml"
    }
    ConfigCategory {
        name: i18n("Tasks")
        icon: "preferences-system-windows"
        source: "ConfigTasks.qml"
    }
    ConfigCategory {
        name: i18n("Pinned apps")
        icon: "emblem-favorite"
        source: "ConfigPinned.qml"
    }
}
