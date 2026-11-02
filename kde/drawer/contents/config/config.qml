import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "preferences-desktop-icons"
        source: "ConfigGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Pinned apps")
        icon: "emblem-favorite"
        source: "ConfigPinned.qml"
    }
}
