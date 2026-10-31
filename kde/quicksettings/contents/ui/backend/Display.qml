import QtQuick
import org.kde.plasma.private.brightnesscontrolplugin
import org.kde.plasma.workspace.dbus as DBus
import org.kde.plasma.plasma5support as P5Support

Item {
    readonly property bool brightnessAvailable: screens.isBrightnessAvailable
    readonly property var displays: screens.displays
    readonly property bool darkMode: DarkModeControl.darkMode
    readonly property bool nightLightAvailable: !!nightLight.properties.available
    readonly property bool nightLightEnabled: !!nightLight.properties.enabled
    readonly property bool nightLightOn: nightLightEnabled && !NightLightInhibitor.inhibited

    function setBrightness(displayName, value) {
        screens.setBrightness(displayName, value);
    }
    function setDarkMode(on) {
        // A manual choice must survive logout, so stop time-based switching.
        shell.connectSource("kwriteconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel false");
        DarkModeControl.darkMode = on;
    }
    function toggleNightLight() {
        NightLightInhibitor.toggleInhibition();
    }

    ScreenBrightnessControl { id: screens }

    P5Support.DataSource {
        id: shell
        engine: "executable"
        onNewData: source => disconnectSource(source)
    }

    DBus.Properties {
        id: nightLight
        busType: DBus.BusType.Session
        service: "org.kde.KWin.NightLight"
        path: "/org/kde/KWin/NightLight"
        iface: "org.kde.KWin.NightLight"
    }
}
