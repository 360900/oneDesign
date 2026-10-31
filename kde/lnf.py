"""Global theme (look-and-feel) packages: defaults, floating topbar + dock layout, splash."""
import json

LAYOUT = """// oneDesign: floating top bar + floating dock
var screenGeo = screenGeometry(0);

var bar = new Panel;
bar.location = "top";
bar.height = 36;
bar.floating = true;
bar.lengthMode = "fill";
bar.hiding = "none";
// Keeps the square pager cells clear of the bar's rounded corner
var lead = bar.addWidget("org.kde.plasma.panelspacer");
lead.currentConfigGroup = ["General"];
lead.writeConfig("expanding", false);
lead.writeConfig("length", 6);
bar.addWidget("org.kde.plasma.pager");
bar.addWidget("org.kde.plasma.panelspacer");
var clock = bar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateDisplayFormat", "BesideTime");
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "ddd d MMM");
bar.addWidget("org.kde.plasma.notifications");
bar.addWidget("org.kde.plasma.panelspacer");
// Tray keeps only app (StatusNotifier) icons and context-only items; the rest lives in Quick Settings
var tray = bar.addWidget("org.kde.plasma.systemtray");
// Plasma >= 6.x nests tray items in the tray applet itself; older versions use a separate containment
var trayBox = desktopById(tray.readConfig("SystrayContainmentId")) || tray;
{
    trayBox.currentConfigGroup = ["General"];
    trayBox.writeConfig("knownItems", [%TRAY_KNOWN%]);
    trayBox.writeConfig("extraItems", [%TRAY_KEEP%]);
    trayBox.writeConfig("showAllItems", true);
}
bar.addWidget("org.onedesign.quicksettings");

var dock = new Panel;
dock.location = "bottom";
dock.height = 60;
dock.floating = true;
dock.alignment = "center";
dock.lengthMode = "fit";
dock.hiding = "dodgewindows";
var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [%LAUNCHERS%]);
tasks.writeConfig("iconSpacing", 1);
tasks.writeConfig("maxStripes", 1);
// Launcher lives in the dock so its "Pin to Task Manager" action targets the dock
dock.addWidget("org.kde.plasma.marginsseparator");
var kick = dock.addWidget("org.kde.plasma.kickoff");
kick.currentConfigGroup = ["General"];
kick.writeConfig("icon", "view-app-grid-symbolic");

var desktopsArray = desktopsForActivity(currentActivity());
for (var j = 0; j < desktopsArray.length; j++) {
    desktopsArray[j].wallpaperPlugin = "org.kde.image";
}
"""

TRAY_KEEP = ["org.kde.plasma.clipboard"]
TRAY_HIDE = ["org.kde.plasma.cameraindicator", "org.kde.plasma.keyboardlayout", "org.kde.plasma.manage-inputmethod", "org.kde.plasma.devicenotifier",
             "org.kde.plasma.printmanager", "org.kde.kscreen", "org.kde.kupapplet", "org.kde.plasma.addons.katesessions", "org.kde.plasma.battery",
             "org.kde.plasma.bluetooth", "org.kde.plasma.brightness",
             "org.kde.plasma.diskquota", "org.kde.plasma.dwellclicker", "org.kde.plasma.keyboardindicator",
             "org.kde.plasma.mediacontroller", "org.kde.plasma.networkmanagement", "org.kde.plasma.notifications",
             "org.kde.plasma.trash", "org.kde.plasma.vault", "org.kde.plasma.volume", "org.kde.plasma.weather",
             "org.kde.kdeconnect"]

LAUNCHERS = ["preferred://filemanager", "preferred://browser", "applications:org.kde.konsole.desktop",
             "applications:org.kde.kate.desktop", "applications:org.kde.gwenview.desktop",
             "applications:systemsettings.desktop"]

SPLASH = """import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root
    color: "%BG%"
    property int stage

    onStageChanged: {
        if (stage == 2) {
            intro.running = true;
        }
        bar.width = Math.min(stage / 6, 1) * track.width;
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0

        Rectangle {
            id: mark
            width: Kirigami.Units.gridUnit * 5
            height: width
            radius: width * 0.3
            anchors.centerIn: parent
            color: "%MARK%"
            Rectangle {
                width: parent.width * 0.42
                height: width
                radius: width / 2
                anchors.centerIn: parent
                color: "transparent"
                border.width: parent.width * 0.11
                border.color: "%ONMARK%"
            }
        }

        Rectangle {
            id: track
            width: Kirigami.Units.gridUnit * 8
            height: 4
            radius: 2
            color: "%TRACK%"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: mark.bottom
            anchors.topMargin: Kirigami.Units.gridUnit * 3
            Rectangle {
                id: bar
                width: 0
                height: parent.height
                radius: 2
                color: "%MARK%"
                Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
            }
        }
    }

    OpacityAnimator {
        id: intro
        running: false
        target: content
        from: 0
        to: 1
        duration: 380
        easing.type: Easing.OutCubic
    }
}
"""


def ident(dark):
    return "org.onedesign.one-dark.desktop" if dark else "org.onedesign.one.desktop"


def metadata(dark):
    name = "One Dark" if dark else "One"
    return json.dumps({
        "KPackageStructure": "Plasma/LookAndFeel",
        "KPlugin": {
            "Authors": [{"Name": "oneDesign"}],
            "Category": "",
            "Description": f"{name}: oneDesign global theme",
            "Id": ident(dark),
            "License": "GPL-3.0-or-later",
            "Name": name,
            "Version": "0.1",
            "Website": "",
        },
        "X-Plasma-APIVersion": "2",
    }, indent=4) + "\n"


def defaults(th, wallpaper):
    dark = th.dark
    return f"""[kdeglobals][KDE]
widgetStyle={'kvantum-dark' if dark else 'kvantum'}

[kdeglobals][General]
ColorScheme={'OneDark' if dark else 'OneLight'}

[kdeglobals][Icons]
Theme={'One-Dark' if dark else 'One'}

[plasmarc][Theme]
name=One

[Wallpaper]
Image={wallpaper}

[kcminputrc][Mouse]
cursorTheme=Adwaita

[kwinrc][org.kde.kdecoration2]
library=org.kde.kwin.aurorae
theme=__aurorae__svg__{'OneDark' if dark else 'OneLight'}

[ksplashrc][KSplash]
Theme={ident(dark)}
"""


def build(th, wallpaper="One-Lagoon"):
    """Returns {relative path: text} for share/plasma/look-and-feel/<ident>/."""
    c = th.c
    launchers = ", ".join(f'"{x}"' for x in LAUNCHERS)
    splash = (SPLASH.replace("%BG%", c["desktop"].hexs).replace("%MARK%", c["accent"].hexs)
              .replace("%ONMARK%", c["onAccent"].hexs).replace("%TRACK%", c["fillStrong"].over(c["desktop"]).hexs))
    return {
        "metadata.json": metadata(th.dark),
        "contents/defaults": defaults(th, wallpaper),
        "contents/layouts/org.kde.plasma.desktop-layout.js": LAYOUT.replace("%LAUNCHERS%", launchers)
            .replace("%TRAY_KNOWN%", ", ".join(f'"{x}"' for x in TRAY_KEEP + TRAY_HIDE))
            .replace("%TRAY_KEEP%", ", ".join(f'"{x}"' for x in TRAY_KEEP)),
        "contents/splash/Splash.qml": splash,
    }
